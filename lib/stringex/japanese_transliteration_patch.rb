require 'stringex/japanese_transliteration'

module Stringex
  module JapaneseTransliterationPatch
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
      Stringex::JapaneseTransliteration.transliterate(string)
    end

    def transliterate_kanji?
      instance.respond_to?(:transliterate_kanji?) && instance.transliterate_kanji?
    end
  end
end
