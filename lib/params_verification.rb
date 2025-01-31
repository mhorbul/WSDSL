# ParamsVerification module.
# Written to verify a service params without creating new objects.
# This module is used on all requests requiring validation and therefore performance
# security and maintainability are critical.
#
# @api public
module ParamsVerification
  
  class ParamError        < StandardError; end #:nodoc
  class NoParamsDefined   < ParamError; end #:nodoc
  class MissingParam      < ParamError; end #:nodoc
  class UnexpectedParam   < ParamError; end #:nodoc
  class InvalidParamType  < ParamError; end #:nodoc
  class InvalidParamValue < ParamError; end #:nodoc
  
  # An array of validation regular expressions.
  # The array gets cached but can be accessed via the symbol key.
  #
  # @return [Hash] An array with all the validation types as keys and regexps as values.
  # @api public
  def self.type_validations
    @type_validations ||= { :integer  => /^-?\d+$/,
                            :float    => /^-?(\d*\.\d+|\d+)$/,
                            :decimal  => /^-?(\d*\.\d+|\d+)$/,
                            :datetime => /^[-\d:T\s]+$/,  # "T" is for ISO date format
                            :boolean  => /^(1|true|TRUE|T|Y|0|false|FALSE|F|N)$/,
                            #:array    => /,/
                          }
  end
  
  # Validation against each required WSDSL::Params::Rule
  # and returns the potentially modified params (with default values)
  # 
  # @param [Hash] params The params to verify (incoming request params)
  # @param [WSDSL::Params] service_params A Playco service param compatible object listing required and optional params 
  # @param [Boolean] ignore_unexpected Flag letting the validation know if unexpected params should be ignored
  #
  # @return [Hash]
  #   The passed params potentially modified by the default rules defined in the service.
  #
  # @example Validate request params against a service's defined param rules
  #   ParamsVerification.validate!(request.params, @service.defined_params)
  # 
  # @api public
  def self.validate!(params, service_params, ignore_unexpected=false)
    
    # Verify that no garbage params are passed, if they are, an exception is raised.
    # only the first level is checked at this point
    unless ignore_unexpected
      unexpected_params?(params, service_params.param_names)
    end
    
    # dupe the params so we don't modify the passed value
    updated_params = params.dup
    # Required param verification
    service_params.list_required.each do |rule|
      updated_params = validate_required_rule(rule, updated_params)
    end
    
    # Set optional defaults if any optional
    service_params.list_optional.each do |rule|
      updated_params = run_optional_rule(rule, updated_params)
    end
    
    # check the namespaced params
    service_params.namespaced_params.each do |param|
      param.list_required.each do |rule|
        updated_params = validate_required_rule(rule, updated_params, param.space_name.to_s)
      end
      param.list_optional.each do |rule|
        updated_params = run_optional_rule(rule, updated_params, param.space_name.to_s)
      end

    end
    
    # verify nested params, only 1 level deep tho
    params.each_pair do |key, value|
      if value.is_a?(Hash)
        namespaced = service_params.namespaced_params.find{|np| np.space_name.to_s == key.to_s}
        raise UnexpectedParam, "Request included unexpected parameter: #{key}" if namespaced.nil?
        unexpected_params?(params[key], namespaced.param_names)
      end
    end
    
    updated_params
  end
  
  
  private
  
  # Validate a required rule against a list of params passed.
  #
  #
  # @param [WSDSL::Params::Rule] rule The required rule to check against.
  # @param [Hash] params The request params.
  # @param [String] namespace Optional param namespace to check the rule against.
  #
  # @return [Hash]
  #   A hash representing the potentially modified params after going through the filter.
  #
  # @api private
  def self.validate_required_rule(rule, params, namespace=nil)
    param_name  = rule.name.to_s
    
    param_value, namespaced_params = extract_param_values(params, param_name, namespace)
    # puts "verify #{param_name} params, current value: #{param_value}"
    
    #This is disabled since required params shouldn't have a default, otherwise, why are they required?
    #if param_value.nil? && rule.options && rule.options[:default]
      #param_value = rule.options[:default]
    #end

    # Checks presence
    if !(namespaced_params || params).keys.include?(param_name)
      raise MissingParam, "'#{rule.name}' is missing - passed params: #{params.inspect}."
    # checks null
    elsif param_value.nil? && !rule.options[:null]
      raise  InvalidParamValue, "Value for parameter '#{param_name}' is missing - passed params: #{params.inspect}."
    # checks type
    elsif rule.options[:type]
      verify_cast(param_name, param_value, rule.options[:type])
    end

    if rule.options[:options] || rule.options[:in]
      choices = rule.options[:options] || rule.options[:in]
      if rule.options[:type]
        # Force the cast so we can compare properly
        param_value = params[param_name] = type_cast_value(rule.options[:type], param_value)
      end
      raise InvalidParamValue, "Value for parameter '#{param_name}' (#{param_value}) is not in the allowed set of values." unless choices.include?(param_value)
    # You can have a "in" rule that also applies a min value since they are mutually exclusive
    elsif rule.options[:minvalue]
      min = rule.options[:minvalue]
      raise InvalidParamValue, "Value for parameter '#{param_name}' is lower than the min accepted value (#{min})." if param_value.to_i < min
    end
    # Returns the updated params
    
    # cast the type if a type is defined and if a range of options isn't defined since the casting should have been done already
    if rule.options[:type] && !(rule.options[:options] || rule.options[:in])
      # puts "casting #{param_value} into type: #{rule.options[:type]}"
      params[param_name] = type_cast_value(rule.options[:type], param_value)
    end
    params
  end


  # Extract the param valie and the namespaced params
  # based on a passed namespace and params
  #
  # @param [Hash] params The passed params to extract info from.
  # @param [String] param_name The param name to find the value.
  # @param [NilClass, String] namespace the params' namespace.
  # @return [Arrays<Object, String>]
  #
  # @api private
  def self.extract_param_values(params, param_name, namespace=nil)
    # Namespace check
    if namespace == '' || namespace.nil?
      [params[param_name], nil]
    else
      # puts "namespace: #{namespace} - params #{params[namespace].inspect}"
      namespaced_params = params[namespace]
      if namespaced_params
        [namespaced_params[param_name], namespaced_params]
      else
        [nil, namespaced_params]
      end
    end
  end
  
  # @param [#WSDSL::Params::Rule] rule The optional rule
  # @param [Hash] params The request params
  # @param [String] namespace An optional namespace
  # @return [Hash] The potentially modified params
  # 
  # @api private
  def self.run_optional_rule(rule, params, namespace=nil)
    param_name  = rule.name.to_s

    param_value, namespaced_params = extract_param_values(params, param_name, namespace)

    if param_value.nil? && rule.options[:default]
      if namespace
        params[namespace][param_name] = param_value = rule.options[:default]
      else
        params[param_name] = param_value = rule.options[:default]
      end
    end
    
    # cast the type if a type is defined and if a range of options isn't defined since the casting should have been done already
    if rule.options[:type] && !param_value.nil?
      if namespace
        params[namespace][param_name] = param_value = type_cast_value(rule.options[:type], param_value)
      else
        params[param_name] = param_value = type_cast_value(rule.options[:type], param_value)
      end
    end

    choices = rule.options[:options] || rule.options[:in]
    if choices && param_value && !choices.include?(param_value)
      raise InvalidParamValue, "Value for parameter '#{param_name}' (#{param_value}) is not in the allowed set of values."
    end
    
    params
  end
  
  def self.unexpected_params?(params, param_names)
    # Raise an exception unless no unexpected params were found
    unexpected_keys = (params.keys - param_names)
    unless unexpected_keys.empty?
      raise UnexpectedParam, "Request included unexpected parameter(s): #{unexpected_keys.join(', ')}"
    end
  end
  
  
  def self.type_cast_value(type, value)
    case type
    when :integer
      value.to_i
    when :float, :decimal
      value.to_f
    when :string
      value.to_s
    when :boolean
      if value.is_a? TrueClass
        true
      elsif value.is_a? FalseClass
        false
      else
        case value.to_s
        when /^(1|true|TRUE|T|Y)$/
          true
        when /^(0|false|FALSE|F|N)$/
          false
        else
          raise InvalidParamValue, "Could not typecast boolean to appropriate value"
        end
      end
    # An array type is a comma delimited string, we need to cast the passed strings.
    when :array
      value.respond_to?(:split) ? value.split(',') : value
    when :binary, :array, :file
      value
    else
      value
    end
  end
  
  # Checks that the value's type matches the expected type for a given param
  #
  # @param [Symbol, String] Param name used if the verification fails and that an error is raised.
  # @param [#to_s] The value to validate.
  # @param [Symbol] The expected type, such as :boolean, :integer etc...
  # @raise [InvalidParamType] Custom exception raised when the validation isn't found or the value doesn't match.
  #
  # @return [Nil]
  # @api public
  # TODO raising an exception really isn't a good idea since it forces the stack to unwind.
  # More than likely developers are using exceptions to control the code flow and a different approach should be used.
  # Catch/throw is a bit more efficient but is still the wrong approach for this specific problem.
  def self.verify_cast(name, value, expected_type)
    validation = ParamsVerification.type_validations[expected_type.to_sym]
    unless validation.nil? || value.to_s =~ validation
      raise InvalidParamType, "Value for parameter '#{name}' (#{value}) is of the wrong type (expected #{expected_type})"
    end
  end
  
end
