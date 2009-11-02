module Watchr
  module EventHandler
    module Unix
    
      @defaults = []

      class << self
        attr_reader :defaults

        def default
          defaults.empty? &&
            begin; require( 'watchr/event_handlers/rev' );
            rescue LoadError => e; end
          defaults.empty? &&
            begin require( 'watchr/event_handlers/portable' );
              defaults << Watchr::EventHandler::Portable;
            end
          defaults[0]
        end

      end

    end
  end
end
