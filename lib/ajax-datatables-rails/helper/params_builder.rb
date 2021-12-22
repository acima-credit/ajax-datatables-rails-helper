# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class ParamsBuilder
      module Transformations
        module SanitizeEmptyDataColumns
          module_function

          def call(full_params, _columns)
            param_columns = full_params[:columns]
            return false unless param_columns.present?

            changed = false
            param_columns.each do |idx, column_param|
              next if column_param[:data].present?

              changed = true
              param_columns.delete idx
            end
            changed
          end
        end

        module ApplyColumnDefaults
          module_function

          def call(column_params, column)
            search = column.search
            return false unless search.present?

            value = column_params.dig 'search', 'value'
            return if value.present?

            default = search[:default]
            return unless default.present?

            column_params[:search][:value] = default
            true
          end
        end

        module ColumnDateRangeSearches
          module_function

          def today
            Time.current.to_date
          end

          def date_pair(column, date_from, date_to = nil)
            delimiter = column.search&.dig(:delimiter) || '|'
            date_to ||= date_from if date_to.nil?
            format '%s%s%s', date_from.iso8601, delimiter, date_to.iso8601
          end

          def dictionary
            @dictionary ||= {
              today: ->(_column_params, column) { date_pair column, today },
              yesterday: ->(_column_params, column) { date_pair column, today - 1 },
              last_7_days: ->(_column_params, column) { date_pair column, today - 6, today },
              last_30_days: ->(_column_params, column) { date_pair column, today - 29, today },
              this_month: ->(_column_params, column) {
                bom = today.at_beginning_of_month
                date_pair column, bom, today
              },
              last_month: ->(_column_params, column) {
                eom = today.at_beginning_of_month - 1
                date_pair column, eom.at_beginning_of_month, eom
              },
              last_3_months: ->(_column_params, column) { date_pair column, today - 89, today }
            }.with_indifferent_access
          end

          def call(column_params, column)
            search = column.search
            return false unless search.present? && search[:cond] == :date_range

            value = column_params.dig 'search', 'value'
            return false unless dictionary.key?(value)

            column_params[:search][:value] = dictionary[value].call column_params, column
            true
          end
        end
      end

      def self.transformations
        @transformations ||= {
          general: [
            # ->(params, columns) { ... },
            Transformations::SanitizeEmptyDataColumns
          ],
          columns: [
            # ->(column_params, column) { ... },
            Transformations::ApplyColumnDefaults,
            Transformations::ColumnDateRangeSearches
          ]
        }
      end

      # @param [Column] column
      def self.build(params, columns)
        new(params, columns).build
      end

      # @param [ActionController::Parameters] params
      # @param [Array<Column>] columns array
      def initialize(params, columns)
        @params = params
        @columns = columns
        @final_params = HashWithIndifferentAccess.new
      end

      def build
        build_original

        run_general_transformations
        run_column_transformations

        build_final
      end

      private

      def build_original
        @params.each { |key, value| @final_params[key] = build_value(value) }
      end

      def build_value(value)
        case value
        when Hash, ActionController::Parameters
          build_hash value
        when Array
          build_array value
        else
          build_single value
        end
      end

      def build_hash(value)
        HashWithIndifferentAccess.new.tap do |hsh|
          value.each_key do |k|
            hsh[k] = build_value value[k]
          end
        end
      end

      def build_array(value)
        value.map { |x| build_value x }
      end

      def build_single(value)
        case value
        when TrueClass, FalseClass
          value
        else
          value.to_s
        end
      end

      def param_columns
        @final_params[:columns]
      end

      def run_general_transformations
        transformations = self.class.transformations[:general]
        return unless transformations.present?

        transformations.each do |transformation|
          transformation.call @final_params, @columns
        end
      end

      def run_column_transformations
        return unless param_columns.present?

        transformations = self.class.transformations[:columns]
        return unless transformations.present?

        @columns.each do |name, column|
          found_params = param_columns.values.find { |x| name.to_s == x[:data] }
          next unless found_params.present?

          transformations.each do |transformation|
            transformation.call found_params, column
          end
        end
      end

      def build_final
        ActionController::Parameters.new @final_params
      end
    end
  end
end
