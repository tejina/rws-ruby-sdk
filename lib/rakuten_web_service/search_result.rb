module RakutenWebService
  class SearchResult
    include Enumerable

    def initialize(params, resource_class)
      @params = params.dup
      @resource_class = resource_class
      @client = RakutenWebService::Client.new(@resource_class.endpoint)
    end

    def each
      params = @params
      response = query
      begin
        resources = @resource_class.parse_response(response.body)
        resources.each do |resource|
          yield resource
        end

        break unless has_next_page?
        response = query(params.merge('page' => response.body['page'] + 1))
      end while(response) 
    end

    def params
      return {} if @params.nil?
      @params.dup 
    end

    def has_next_page?
      @response.body['page'] && @response.body['page'] < @response.body['pageCount']
    end

    def order(options)
      new_params = @params.dup
      if options.is_a? Hash
        key, sort_order = *(options.to_a.last)
        key = camelize(key.to_s)
        new_params[:sort] = case sort_order.to_s.downcase
                         when 'desc'
                           "-#{key}"
                         when 'asc'
                           "+#{key}"
                         end
      elsif options.to_s == 'standard'
        new_params[:sort] = 'standard' 
      else 
        raise ArgumentError, "Invalid Sort Option: #{options.inspect}"
      end
      self.class.new(new_params, @resource_class)
    end

    private
    def query(params=nil)
      retries = RakutenWebService.configuration.max_retries
      begin 
        @response = @client.get(params || @params)
      rescue RWS::TooManyRequests => e
        if retries > 0
          retries -= 1
          sleep 1
          retry
        else
          raise e
        end
      end
      @response
    end

    def camelize(str)
      str = str.downcase
      str = str.gsub(/([a-z]+)_([a-z]+)/) do
        "#{$1.capitalize}#{$2.capitalize}"
      end
      str[0] = str[0].downcase
      str
    end
  end
end
