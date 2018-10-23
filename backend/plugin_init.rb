if AppConfig.has_key?(:as_history)
  AppConfig[:as_history][:models_with_history].map {|model| 
    Kernel.const_get(model).prepend(Auditable)
}
else
  raise 'No config for as_history plugin!'
end

