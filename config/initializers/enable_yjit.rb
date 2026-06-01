# Automatically enable YJIT as of Ruby 3.3, as it brings very
# sizeable performance improvements.
#
# Tuned for ARM VM with limited memory: call_threshold=10 compiles
# hot methods sooner for better steady-state performance.
if defined? RubyVM::YJIT.enable
  Rails.application.config.after_initialize do
    RubyVM::YJIT.enable
  end
end
