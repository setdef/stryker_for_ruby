# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/patch"
require "stryker/instrumenter/patches"

# Checks how patches change the bytes of a source.
class PatchesTest < Minitest::Test
  Patches = Stryker::Instrumenter::Patches
  private_constant(:Patches)

  # The patches that +changes+ name, each the offsets of the bytes it replaces
  # and the replacement.
  def apply(source, *changes)
    patches = changes.map { |start_offset, end_offset, text| Stryker::Instrumenter::Patch.new(start_offset, end_offset, text) }
    Patches.apply(source, patches)
  end

  def test_each_patch_replaces_the_bytes_it_names_in_the_original_source
    assert_equal("a-b-c", apply("a+b+c", [1, 2, "-"], [3, 4, "-"]))
  end

  def test_a_patch_may_come_before_a_later_one_in_the_list_and_after_it_in_the_source
    assert_equal("a-b-c", apply("a+b+c", [3, 4, "-"], [1, 2, "-"]))
  end

  def test_a_patch_that_replaces_nothing_inserts
    assert_equal("a(b)c", apply("abc", [1, 1, "("], [2, 2, ")"]))
  end

  def test_of_patches_at_one_offset_the_one_listed_first_goes_last_in_the_result
    assert_equal("(x)", apply("a", [1, 1, ")"], [0, 1, "x"], [0, 0, "("]))
  end

  def test_two_insertions_at_one_offset_put_the_later_one_in_front
    assert_equal("ba", apply("", [0, 0, "a"], [0, 0, "b"]))
  end

  def test_a_patch_may_remove_bytes
    assert_equal("ac", apply("abc", [1, 2, ""]))
  end

  def test_the_result_has_the_encoding_of_the_source
    source = "é".encode(Encoding::ISO_8859_1)

    assert_equal(Encoding::ISO_8859_1, apply(source, [0, 0, "".b]).encoding)
  end

  def test_the_replacement_may_be_bytes_of_another_encoding
    assert_equal("a\xFFb".b, apply("ab", [1, 1, "\xFF".b]).b)
  end

  def test_no_patches_leave_the_source
    assert_equal("p 1\n", apply("p 1\n"))
  end
end
