module Wake
  module EventHandler
    module Unix
    
      @defaults = []

      class << self
        attr_reader :defaults

        def default
          defaults.empty? &&
            begin; require( 'wake/event_handlers/rev' );
            rescue LoadError => e; end
          defaults.empty? &&
            begin require( 'wake/event_handlers/portable' );
              defaults << Wake::EventHandler::Portable;
            end
          defaults[0]
        end

      end

    end
  end
end
