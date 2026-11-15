# frozen_string_literal: true

require 'time'

module Stoop
  # Output formatting helpers shared by the CLI.
  module Format
    module_function

    def price(value)
      "Rp #{value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
    end

    def time(iso8601)
      Time.parse(iso8601).localtime.strftime('%Y-%m-%d %H:%M')
    rescue ArgumentError
      iso8601
    end

    def percent_change(previous, current)
      return '-' if previous.nil? || previous.zero?

      change = ((current - previous).to_f / previous) * 100
      format('%+.1f%%', change)
    end

    def truncate(text, length)
      text = text.to_s
      text.length > length ? "#{text[0, length - 3]}..." : text
    end

    # Renders a plain-text table with a dashed separator under the header.
    def table(headers, rows)
      widths = ([headers] + rows).transpose.map { |column| column.map { |cell| cell.to_s.length }.max }
      lines = []
      lines << join_row(headers, widths)
      lines << widths.map { |width| '-' * width }.join('  ')
      rows.each { |row| lines << join_row(row, widths) }
      lines.join("\n")
    end

    def join_row(row, widths)
      row.map.with_index { |cell, i| cell.to_s.ljust(widths[i]) }.join('  ').rstrip
    end

    # RFC 4180 cell: quote when the value contains a comma, quote or newline.
    def csv_cell(value)
      cell = value.to_s
      return cell unless cell.match?(/[",\r\n]/)

      "\"#{cell.tr('"', '""')}\""
    end

    def csv_row(fields)
      "#{fields.map { |field| csv_cell(field) }.join(',')}\n"
    end
  end
end
