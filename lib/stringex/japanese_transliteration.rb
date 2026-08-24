require 'open3'

module Stringex
  module JapaneseTransliteration
    JAP_CHAR_REGEXP = /[\p{Han}\p{Hiragana}\p{Katakana}]+/.freeze

    class << self
      def transliterate(string)
        return string unless contains_japanese?(string)
        return string unless iconv_installed? && kakasi_installed?

        iconv_output, _, iconv_status = Open3.capture3(
          'iconv', '-f', 'utf8', '-t', 'eucjp', stdin_data: string
        )
        return string unless iconv_status.success?

        words_output, _, words_status = Open3.capture3(
          'kakasi', '-i', 'euc', '-w', stdin_data: iconv_output
        )
        return string unless words_status.success?

        transliterated_output, _, transliteration_status = Open3.capture3(
          'kakasi', '-i', 'euc', '-Ha', '-Ka', '-Ja', '-Ea', '-ka',
          stdin_data: words_output
        )
        return string unless transliteration_status.success?

        transliterated = transliterated_output.chomp.delete('^')
        transliterated.empty? ? string : transliterated
      rescue StandardError
        string
      end

      def contains_japanese?(string)
        !JAP_CHAR_REGEXP.match(string).nil?
      end

      def kakasi_installed?
        return @kakasi_installed if defined?(@kakasi_installed)

        @kakasi_installed = !!system(
          'kakasi', in: File::NULL, out: File::NULL, err: File::NULL
        )
        log_missing_binary('kakasi') unless @kakasi_installed
        @kakasi_installed
      rescue StandardError
        @kakasi_installed = false
        log_missing_binary('kakasi')
        false
      end

      def iconv_installed?
        return @iconv_installed if defined?(@iconv_installed)

        @iconv_installed = !!system(
          'iconv', '--version', out: File::NULL, err: File::NULL
        )
        log_missing_binary('iconv') unless @iconv_installed
        @iconv_installed
      rescue StandardError
        @iconv_installed = false
        log_missing_binary('iconv')
        false
      end

      private

      def log_missing_binary(binary)
        message = "Stringex: #{binary} not installed, skipping kanji transliteration"
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.warn(message)
        else
          warn(message)
        end
      rescue StandardError
        warn(message)
      end
    end
  end
end
