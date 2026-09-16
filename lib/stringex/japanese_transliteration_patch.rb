# frozen_string_literal: true

require 'English'

module Stringex
  module JapaneseTransliterationPatch
    JAP_CHAR_REGEXP ||= /[\p{Han}\p{Hiragana}\p{Katakana}]+/.freeze
    LOOKALIKES ||= { "\uFF5E" => "\u301C", "\uFF0D" => '-', "\u2212" => '-' }.freeze
    KAKASI_ERR ||= 'Kakasi not installed, skipping kanji transliteration'
    ICONV_ERR ||= 'Iconv not installed, skipping kanji transliteration'

    def modify_base_url
      root = instance.send(settings.attribute_to_urlify).to_s

      suffix = ''
      suffix_attribute = settings.suffix_attribute
      if suffix_attribute
        suffix_attribute = suffix_attribute.call(instance) if suffix_attribute.lambda?
        suffix = instance.send(suffix_attribute) if suffix_attribute
      end
      root += "-#{suffix}" if suffix.present?

      root = transliterate_kanji(root)
      self.base_url = root.to_url(configuration.string_extensions_settings)
    end

    private

    def transliterate_kanji(string)
      return string unless transliterate_kanji?
      return string unless contains_japanese?(string)
      return string unless iconv_installed?
      return string unless kakasi_installed?

      convertible_runs(string).map { |run| transliterate(run) }.join(' ')
    end

    def convertible_runs(string)
      normalized = string.gsub(/[\uFF5E\uFF0D\u2212]/, LOOKALIKES)

      normalized.chars.chunk_while { |first, second| convertible?(first) == convertible?(second) }
                .map(&:join)
    end

    def transliterate(run)
      return run unless convertible?(run) && run.match?(JAP_CHAR_REGEXP)

      command = "set -o pipefail; printf '%s\\n' #{Shellwords.escape(run)}"\
        ' | iconv -f utf8 -t eucjp 2>/dev/null'\
        ' | kakasi -i euc -w | kakasi -i euc -Ha -Ka -Ja -Ea -ka'
      transliterated = `/bin/bash -c #{Shellwords.escape(command)}`
      return run unless $CHILD_STATUS.success?

      transliterated.strip.presence || run
    end

    def transliterate_kanji?
      instance.respond_to?(:transliterate_kanji?) && instance.transliterate_kanji?
    end

    def contains_japanese?(string)
      string =~ JAP_CHAR_REGEXP
    end

    def convertible?(string)
      string.encode('EUC-JP')
      true
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      false
    end

    def kakasi_installed?
      `echo test | kakasi` == "test\n"
    rescue StandardError
      Rails.logger.error(KAKASI_ERR)
      false
    end

    def iconv_installed?
      `iconv --version`
      $CHILD_STATUS.success?
    rescue StandardError
      Rails.logger.error(ICONV_ERR)
      false
    end
  end
end
