# frozen_string_literal: true

module RSpecTelemetry
  module Trace
    module Viewer
      # Owns "follow mode": draining a live source into the Document, keeping the
      # cursor parked at the tail, and advancing the pending spinner.
      class FollowController
        SPINNER = %w[| / - \\].freeze

        def initialize(source:, active:)
          @source = source
          @active = active
          @stick = active
          @spin = 0
        end

        def active? = @active
        def wants_tick? = @active
        def spinner = SPINNER[@spin % SPINNER.length]

        # Flip follow on/off; resume tail-sticking only when parked at the end.
        def toggle(at_end:)
          @active = !@active
          @stick = @active && at_end
          @active
        end

        # Re-evaluate sticking after the cursor moves (e.g. App#go_to).
        def reset_stick(at_end:)
          @stick = @active && at_end
        end

        # Advance the spinner and fold any new source lines into the document.
        def drain(document)
          return false unless @active

          @spin += 1
          lines = @source ? @source.drain : []
          lines.each { |line| document.apply(line) }
          !lines.empty?
        end

        # Keep the cursor parked at the tail while sticking.
        def stick(list)
          list.to_end if @stick
        end
      end
    end
  end
end
