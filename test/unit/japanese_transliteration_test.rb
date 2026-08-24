require 'test_helper'
require 'stringex/japanese_transliteration_patch'

class JapaneseTransliterationTest < Test::Unit::TestCase
  TestInstance = Struct.new(:value, :enabled) do
    def transliterate_kanji?
      enabled
    end
  end

  TestAdapter = Struct.new(:instance) do
    include Stringex::JapaneseTransliterationPatch
  end

  def test_transliterates_opted_in_kanji
    omit_without_kakasi

    assert_equal 'saiyou', transliterate('採用', enabled: true)
    sap_title = transliterate('SAPデータ活用コンサルタント', enabled: true)
    assert_includes sap_title, 'deta'
    assert_includes sap_title, 'katsuyou'
    refute_includes sap_title, '^'
  end

  def test_leaves_opted_out_strings_unchanged
    input = '採用'

    assert_equal input, transliterate(input, enabled: false)
  end

  def test_leaves_strings_without_japanese_untouched
    input = 'English title'

    assert_equal input, transliterate(input, enabled: true)
  end

  def test_handles_apostrophes_and_spaces_without_escape_characters
    omit_without_kakasi

    input = "O'Reilly SAPデータ活用コンサルタント"

    result = transliterate(input, enabled: true)

    assert_includes result, "O'Reilly"
    assert_includes result, 'katsuyou'
    refute_match(/\\ /, result)
  end

  def test_falls_back_when_kakasi_is_unavailable
    input = '採用'

    original_check = Stringex::JapaneseTransliteration.method(:kakasi_installed?)
    Stringex::JapaneseTransliteration.define_singleton_method(:kakasi_installed?) { false }
    begin
      assert_equal input, transliterate(input, enabled: true)
    ensure
      Stringex::JapaneseTransliteration.define_singleton_method(
        :kakasi_installed?, &original_check
      )
    end
  end

  private

  def kakasi_available?
    Stringex::JapaneseTransliteration.kakasi_installed?
  end

  def omit_without_kakasi
    omit 'kakasi is not installed' unless kakasi_available?
  end

  def transliterate(value, enabled:)
    adapter = TestAdapter.new(TestInstance.new(value, enabled))
    adapter.send(:transliterate_kanji, value)
  end
end
