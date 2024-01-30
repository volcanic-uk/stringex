module Stringex
  module JapaneseTransliterationPatch
    JAP_CHAR_REGEXP ||= /[\p{Han}\p{Hiragana}\p{Katakana}]+/.freeze
    KAKASI_ERR ||= 'Kakasi not installed, skipping kanji transliteration'.freeze
    ICONV_ERR ||= 'Iconv not installed, skipping kanji transliteration'.freeze

    def modify_base_url
      root = instance.send(settings.attribute_to_urlify).to_s

      root = transliterate_kanji(root)
      self.base_url = root.to_url(configuration.string_extensions_settings)
    end

    private

    def transliterate_kanji(string)
      return string unless transliterate_kanji?
      return string unless contains_japanese?(string)
      return string unless iconv_installed?
      return string unless kakasi_installed?

      safe_string = Shellwords.escape(string)

      cmd = "echo '#{safe_string}'"\
        ' | iconv -f utf8 -t eucjp'\
        ' | kakasi -i euc -w | kakasi -i euc -Ha -Ka -Ja -Ea -ka'

      `#{cmd}`
    end

    def transliterate_kanji?
      instance.respond_to?(:transliterate_kanji?) && instance.transliterate_kanji?
    end

    def contains_japanese?(string)
      string =~ JAP_CHAR_REGEXP
    end

    def kakasi_installed?
      `echo test | kakasi` == "test\n"
    rescue StandardError
      Rails.logger.error(KAKASI_ERR)
    end

    def iconv_installed?
      `iconv --version`
    rescue StandardError
      Rails.logger.error(ICONV_ERR)
    end
  end
end