class WSDSL
  # Response DSL class
  # @api public
  class Response

    # The list of all the elements inside the response
    #
    # @return [Array<WSDSL::Response::Element>]
    # @api public
    attr_reader :elements

    # The list of all the arays inside the response
    #
    # @return [Array<WSDSL::Response::Array>]
    attr_reader :arrays

    def initialize
      @elements = []
      @arrays  = []
    end

    # Lists all top level simple elements and array elements.
    #
    # @return [Array<WSDSL::Response::Element, WSDSL::Response::Array>]
    def nodes 
      elements + arrays
    end

    # Shortcut to automatically create a node of array type.
    # Useful when describing a JSON response.
    #
    # @param [String, Symbol] name the name of the element.
    # @param [Hash] opts the element options.
    # @see Vector#initialize
    def array(name, type=nil)
      vector = Vector.new(name, type)
      yield(vector) if block_given?
      @arrays << vector
    end

    # Defines a new element and yields the content of an optional block
    # Each new element is then stored in the elements array.
    #
    # @param [Hash] opts Options used to define the element
    # @option opts [String, Symbol] :name The element name
    # @option opts [String, Symbol] :type The optional type
    #
    # @yield [WSDSL::Response::Element] the newly created element
    # @example create an element called 'my_stats'.
    #   service.response do |response|
    #    response.element(:name => "my_stats", :type => 'Leaderboard')
    #   end
    #
    # @return [WSDSL::Response::Element]
    # @api public
    def element(opts={})
      el = Element.new(opts[:name], opts[:type])
      yield(el) if block_given?
      @elements << el
      el
    end

    # Defines an anonymous element
    # Useful for JSON response description
    #
    # @return [WSDSL::Response::Element]
    def object
      yield element
    end

    # Returns a response element object based on its name
    # @param [String, Symbol] The element name we want to match
    #
    # @return [WSDSL::Response::Element]
    # @api public
    def element_named(name)
      @elements.find{|e| e.name.to_s == name.to_s}
    end

    # The Response element class describing each element of a service response.
    # Instances are usually not instiated directly but via the Response#element accessor.
    #
    # @see WSDSL::Response#element
    # @api public
    class Element

      # @return [String, #to_s] The name of the element
      # @api public
      attr_reader :name

      # @api public
      attr_reader :type

      # The optional lookup key of an object
      attr_reader :key

      # @return [Array<WSDSL::Response::Element::Attribute>] An array of attributes
      # @api public
      attr_reader :attributes

      # @return [Array<WSDSL::Response::Element::MetaAttribute>] An array of meta attributes
      # @api public
      attr_reader :meta_attributes

      # @return [Array] An array of vectors/arrays
      # @api public
      attr_reader :vectors

      # @return [WSDSL::Documentation::ElementDoc] Response element documentation
      # @api public
      attr_reader :doc

      # @return [NilClass, Array<WSDSL::Response::Element>] The optional nested elements
      attr_reader :elements

      # Alias to use a JSON/JS jargon instead of XML.
      alias :properties :attributes

      # Alias to use a JSON/JS jargon instead of XML.
      alias :objects :elements

      # param [String, Symbol] name The name of the element
      # param [String, Symbol] type The optional type of the element
      # @api public
      def initialize(name, type=nil)
        # sets a documentation placeholder since the response doc is defined at the same time
        # the response is defined.
        @doc        = Documentation::ElementDoc.new(name)
        @name       = name
        @type       = type
        @attributes = []
        @meta_attributes = []
        @vectors    = []
        @key        = nil
        # we don't need to initialize the nested elements, by default they should be nil
      end

      # sets a new attribute and returns the entire list of attributes
      #
      # @param [Hash] opts An element's attribute options
      # @option opts [String, Symbol] attribute_name The name of the attribute, the value being the type
      # @option opts [String, Symbol] :doc The attribute documentation
      # @option opts [String, Symbol] :mock An optional mock value used by service related tools
      # 
      # @example Creation of a response attribute called 'best_lap_time'
      #   service.response do |response|
      #    response.element(:name => "my_stats", :type => 'Leaderboard') do |e|
      #      e.attribute "best_lap_time"       => :float,    :doc => "Best lap time in seconds."
      #    end
      #   end
      #
      # @return [Array<WSDSL::Response::Attribute>]
      # @api public
      def attribute(opts)
        raise ArgumentError unless opts.is_a?(Hash)
        # extract the documentation part and add it where it belongs
        new_attribute = Attribute.new(opts)
        @attributes << new_attribute
        # document the attribute if description available
        # we might want to have a placeholder message when a response attribute isn't defined
        if opts.has_key?(:doc)
          @doc.attribute(new_attribute.name, opts[:doc])
        end
        @attributes
      end

      # sets a new meta attribute and returns the entire list of meta attributes
      #
      # @param [Hash] opts An element's attribute options
      # @option opts [String, Symbol] attribute_name The name of the attribute, the value being the type
      # @option opts [String, Symbol] :mock An optional mock value used by service related tools
      # 
      # @example Creation of a response attribute called 'best_lap_time'
      #   service.response do |response|
      #    response.element(:name => "my_stats", :type => 'Leaderboard') do |e|
      #      e.meta_attribute "id"       => :key
      #    end
      #   end
      #
      # @return [Array<WSDSL::Response::MetaAttribute>]
      # @api public
      def meta_attribute(opts)
        raise ArgumentError unless opts.is_a?(Hash)
        # extract the documentation part and add it where it belongs
        new_attribute = MetaAttribute.new(opts)
        @meta_attributes << new_attribute
        @meta_attributes
      end

      # Defines an array aka vector of elements.
      #
      # @param [String, Symbol] name The name of the array element.
      # @param [String, Symbol] type Optional type information, useful to store the represented 
      #        object types for instance.
      #
      # @param [Proc] &block
      #   A block to execute against the newly created array.
      # 
      # @example Defining an element array called 'player_creation_rating'
      #   element.array 'player_creation_rating', 'PlayerCreationRating' do |a|
      #     a.attribute :comments  => :string
      #     a.attribute :player_id => :integer
      #     a.attribute :rating    => :integer
      #     a.attribute :username  => :string
      #   end
      # @yield [Vector] the newly created array/vector instance
      # @see Element#initialize
      # 
      # @return [Array<WSDSL::Response::Vector>]
      # @api public
      def array(name, type=nil)
        vector = Vector.new(name, type)
        yield(vector) if block_given?
        @vectors << vector
      end

      # Returns the arrays/vectors contained in the response.
      # This is an alias to access @vectors
      # @see @vectors
      #
      # @return [Array<WSDSL::Response::Vector>]
      # @api public
      def arrays
        @vectors
      end

      # Defines a new element and yields the content of an optional block
      # Each new element is then stored in the elements array.
      #
      # @param [Hash] opts Options used to define the element
      # @option opts [String, Symbol] :name The element name
      # @option opts [String, Symbol] :type The optional type
      #
      # @yield [WSDSL::Response::Element] the newly created element
      # @example create an element called 'my_stats'.
      #   service.response do |response|
      #    response.element(:name => "my_stats", :type => 'Leaderboard')
      #   end
      #
      # @return [Array<WSDSL::Response::Element>]
      # @api public
      def element(opts={})
        el = Element.new(opts[:name], opts[:type])
        yield(el) if block_given?
        @elements ||= []
        @elements << el
        el
      end

      # Shortcut to create a new element.
      #
      # @param [Symbol, String] name the name of the element.
      # @param [Hash] opts the options for the newly created element.
      def object(name, opts={}, &block)
        element(opts.merge(:name => name), &block)
      end

      # Getter/setter for the key meta attribute.
      # A key name can be used to lookup an object by a primary key for instance.
      #
      # @param [Symbol, String] name the name of the key attribute.
      # @param [Hash] opts the options attached with the key.
      def key(name=nil, opts={})
        meta_attribute_getter_setter(:key, name, opts)
      end

      # Getter/setter for the type meta attribute.
      #
      # @param [Symbol, String] name the name of the type attribute.
      # @param [Hash] opts the options attached with the key.
      def type(name=nil, opts={})
        meta_attribute_getter_setter(:type, name, opts)
      end

      # Shortcut to create a string attribute
      #
      # @param [Symbol, String] name the name of the attribute.
      # @param [Hash] opts the attribute options.
      def string(name=nil, opts={})
        attribute({name => :string}.merge(opts))
      end

      # Shortcut to create a string attribute
      #
      # @param [Symbol, String] name the name of the attribute.
      # @param [Hash] opts the attribute options.
      def integer(name=nil, opts={})
        attribute({name => :integer}.merge(opts))
      end

      # Shortcut to create a string attribute
      #
      # @param [Symbol, String] name the name of the attribute.
      # @param [Hash] opts the attribute options.
      def float(name=nil, opts={})
        attribute({name => :float}.merge(opts))
      end

      # Shortcut to create a string attribute
      #
      # @param [Symbol, String] name the name of the attribute.
      # @param [Hash] opts the attribute options.
      def boolean(name=nil, opts={})
        attribute({name => :boolean}.merge(opts))
      end

      # Shortcut to create a string attribute
      #
      # @param [Symbol, String] name the name of the attribute.
      # @param [Hash] opts the attribute options.
      def datetime(name=nil, opts={})
        attribute({name => :datetime}.merge(opts))
      end

      private

      # Create a meta element attribute
      def meta_attribute_getter_setter(type, name, opts)
        if name
          meta_attribute({name => type}.merge(opts))
        else
          # with a fallback to the @type ivar
          meta = meta_attributes.find{|att| att.type == type}
          if meta
            meta.value
          else
            instance_variable_get("@#{type}")
          end
        end
      end

      # Response element's attribute class
      # @api public
      class Attribute

        # @return [String, #to_s] The attribute's name.
        # @api public
        attr_reader :name
        alias :value :name

        # @return [Symbol, String, #to_s] The attribute's type such as boolean, string etc..
        # @api public
        attr_reader :type

        # @return [String] The documentation associated with this attribute.
        # @api public
        attr_reader :doc

        # @see {Attribute#new}
        # @return [Hash, Nil, Object] Could be a hash, nil or any object depending on how the attribute is created.
        # @api public
        attr_reader :opts

        # Takes a Hash or an Array and extract the attribute name, type
        # doc and extra options.
        # If the passed objects is a Hash, the name will be extract from
        # the first key and the type for the first value.
        # An entry keyed by :doc will be used for the doc and the rest will go
        # as extra options.
        #
        # If an Array is passed, the elements will be 'shifted' in this order:
        # name, type, doc, type
        #
        # @param [Hash, Array] o_params
        #
        # @api public
        def initialize(o_params)
          params = o_params.dup
          if params.is_a?(Hash)
            @name, @type = params.shift
            @doc  = params.delete(:doc) if params.has_key?(:doc)
            @opts = params
          elsif params.is_a?(Array)
            @name = params.shift
            @type = params.shift
            @doc  = params.shift
            @opts = params
          end
        end
      end

      # Response's meta attribute meant to set some extra
      # attributes which are not part of the response per se.
      class MetaAttribute < Attribute
      end

    end # of Element

    # Array of objects
    # @api public
    class Vector < Element
    end # of Vector

  end # of Response
end
