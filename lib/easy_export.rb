require "easy_export/version"
require 'active_support'

module EasyExport
  extend ActiveSupport::Concern

  module ClassMethods
    # Declare this method in your model class to define the export configuration.
    #
    # The block will be executed in the context of the ExportConfig, e.g:
    #
    #   exportable do
    #     scope -> { ['some records', ...] }
    #     fields [
    #       ['Header 1', -> { value to return }],
    #       ['Header 2', :method_name],
    #       ['Header 3', 'static value'], ...
    #     ]
    #   end
    #
    # scope: an object that responds to #call and returns a collection of instances
    # fields: an array of tuples where the 1st element is the Header name
    #         and the 2nd is a proc, symbol, or static value to be instance
    #         exec'ed, called as a method on the instance, or just returned, respectively.
    #
    def exportable(&block)
      @export_config ||= ExportConfig.new
      @export_config.partial = name.demodulize.underscore.pluralize
      @export_config.instance_exec &block
    end

    def export_partial; @export_config.partial end
    def export_scope;   @export_config.scope end
    def export_fields;  @export_config.fields end
  end

  # These are the DSL methods available within the `exportable` block
  class ExportConfig
    attr_accessor :partial

    def scope(val = nil)
      val.nil? ? @scope : @scope = val
    end

    def fields(val = nil)
      val.nil? ? @fields : @fields = build_fields(val)
    end

    private

    # Providing fields as an array let's us maintain the ordering
    def build_fields(fields)
      raise ArgumentError, "fields must be an array" unless fields.is_a? Array

      ActiveSupport::OrderedHash.new.tap do |hash|
        fields.each do |header, value_proc|
          hash[header] = value_proc
        end
      end
    end
  end

  class Exporter
    require 'csv'

    # Instantiate an Exporter that will convert a collection of models into
    # a CSV string. The model needs to be setup with `exportable` class method.
    #
    # @options:
    #   model: string name of the model class used to fetch instances to convert.
    #   filter: a string that can be used by the @scope to further filter models
    #   ...any other args needed in the options passed to the @scope.
    #
    # @model: the model class.
    # @scope: a proc or object that responds to #call and takes the @options hash
    #         and returns a scoped collection of instances of @model.
    # @fields: an array of 2 element arrays that represent the header and method
    #          to call on the model to retrieve the value for that column.
    # @header: the first element of every array in @fields
    #
    def initialize(options = {})
      @options = options
      @model   = options[:model].constantize
      # the @model.export_scope is configured via the `exportable` block
      @scope   = options.fetch :scope, @model.export_scope
      # the fields configured via the `exportable` block
      @fields  = options.fetch :fields, @model.export_fields
      @header  = @fields.keys
    end

    def data
      CSV.generate do |csv|
        csv << @header

        scoped_models.each do |model|
          csv << generate_row(model)
        end
      end
    end

    def file_name
      timestamp = I18n.l(Time.zone.now, format: :short_date_only).parameterize
      model_name = @model.name.demodulize.pluralize
      "#{model_name}-#{timestamp}.csv"
    end

    def file_type
      'text/csv'
    end

    protected

    def scoped_models
      @scope.call @options
    end

    # Generate an array representing a CSV row by iterating over @fields
    # and using the 2nd item in each array as a value getter. It can be
    # either a proc that is called in the context of the model, a symbol
    # representing a method to call on the model, or a static value.
    def generate_row(model)
      @fields.map do |_, value_proc|
        if value_proc.is_a? Proc
          begin
            model.instance_exec &value_proc
          rescue NameError => e
            # This happens when the model is a GroupSession hash that was returned by the @scope
            # when the user selects GroupSession in the calendar filters
            # TODO: Have the AppointmentFilter convert those
            # hashes into AR like objects that respond to all
            # the same methods Appointments do.
            # For now, just put an error in this field.
            "Error getting field value"
          end
        elsif model.respond_to? value_proc
          model.send value_proc
        else
          value_proc
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, EasyExport
