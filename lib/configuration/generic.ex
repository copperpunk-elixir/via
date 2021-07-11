defmodule Configuration.Generic do
  require Logger

  @spec native_source?(list()) :: boolean()
  def native_source?(classification) do
    [primary, _secondary] = classification
    primary == 0
  end

  @spec generic_peripheral_classification(binary()) :: list()
  def generic_peripheral_classification(peripheral_type) do
    secondary_class = :rand.uniform()
    possible_types = "abcde"
    max_value = Bitwise.<<<(1, String.length(possible_types))
    primary_class = Enum.reduce(String.graphemes(String.downcase(peripheral_type)),max_value , fn (letter, acc) ->
      case :binary.match(possible_types, letter) do
        :nomatch -> acc
        {location, _} -> acc - Bitwise.<<<(1,location)
      end
     end)
    [primary_class, secondary_class]
  end
end
