defmodule Date.Range do
  @moduledoc """
  Returns an inclusive range between dates.

  Ranges must be created with the `Date.range/2` or `Date.range/3` function.

  The following fields are public:

    * `:first` - the initial date on the range
    * `:last` - the last date on the range
    * `:step` - (since v1.12.0) the step

  The remaining fields are private and should not be accessed.
  """

  @type t :: %__MODULE__{
          first: Date.t(),
          last: Date.t(),
          first_in_iso_days: iso_days(),
          last_in_iso_days: iso_days(),
          step: pos_integer | neg_integer
        }

  @typep iso_days() :: Calendar.iso_days()

  @enforce_keys [:first, :last, :first_in_iso_days, :last_in_iso_days, :step]
  defstruct [:first, :last, :first_in_iso_days, :last_in_iso_days, :step]

  defimpl Enumerable do
    def member?(%{first: %{calendar: calendar}} = range, %Date{calendar: calendar} = date) do
      %{
        first_in_iso_days: first_days,
        last_in_iso_days: last_days,
        step: step
      } = range

      {days, _} = Date.to_iso_days(date)

      cond do
        empty?(range) ->
          {:ok, false}

        first_days <= last_days ->
          {:ok, first_days <= days and days <= last_days and rem(days - first_days, step) == 0}

        true ->
          {:ok, last_days <= days and days <= first_days and rem(days - first_days, step) == 0}
      end
    end

    def member?(_, _) do
      {:ok, false}
    end

    def count(range) do
      {:ok, size(range)}
    end

    def slice(range) do
      %{
        first_in_iso_days: first,
        first: %{calendar: calendar},
        step: step
      } = range

      {:ok, size(range), &slice(first + &1 * step, step, &2, calendar)}
    end

    defp slice(current, _step, 1, calendar) do
      [date_from_iso_days(current, calendar)]
    end

    defp slice(current, step, remaining, calendar) do
      [
        date_from_iso_days(current, calendar)
        | slice(current + step, step, remaining - 1, calendar)
      ]
    end

    def reduce(range, acc, fun) do
      %{
        first_in_iso_days: first_days,
        last_in_iso_days: last_days,
        first: %{calendar: calendar},
        step: step
      } = range

      reduce(first_days, last_days, acc, fun, step, calendar)
    end

    defp reduce(_first_days, _last_days, {:halt, acc}, _fun, _step, _calendar) do
      {:halted, acc}
    end

    defp reduce(first_days, last_days, {:suspend, acc}, fun, step, calendar) do
      {:suspended, acc, &reduce(first_days, last_days, &1, fun, step, calendar)}
    end

    defp reduce(first_days, last_days, {:cont, acc}, fun, step, calendar)
         when step > 0 and first_days <= last_days
         when step < 0 and first_days >= last_days do
      reduce(
        first_days + step,
        last_days,
        fun.(date_from_iso_days(first_days, calendar), acc),
        fun,
        step,
        calendar
      )
    end

    defp reduce(_, _, {:cont, acc}, _fun, _step, _calendar) do
      {:done, acc}
    end

    defp date_from_iso_days(days, Calendar.ISO) do
      {year, month, day} = Calendar.ISO.date_from_iso_days(days)
      %Date{year: year, month: month, day: day, calendar: Calendar.ISO}
    end

    defp date_from_iso_days(days, calendar) do
      {year, month, day, _, _, _, _} =
        calendar.naive_datetime_from_iso_days({days, {0, 86_400_000_000}})

      %Date{year: year, month: month, day: day, calendar: calendar}
    end

    defp size(%Date.Range{first_in_iso_days: first_days, last_in_iso_days: last_days, step: step})
         when step > 0 and first_days > last_days,
         do: 0

    defp size(%Date.Range{first_in_iso_days: first_days, last_in_iso_days: last_days, step: step})
         when step < 0 and first_days < last_days,
         do: 0

    defp size(%Date.Range{first_in_iso_days: first_days, last_in_iso_days: last_days, step: step}),
      do: abs(div(last_days - first_days, step)) + 1

    defp empty?(%Date.Range{
           first_in_iso_days: first_days,
           last_in_iso_days: last_days,
           step: step
         })
         when step > 0 and first_days > last_days,
         do: true

    defp empty?(%Date.Range{
           first_in_iso_days: first_days,
           last_in_iso_days: last_days,
           step: step
         })
         when step < 0 and first_days < last_days,
         do: true

    defp empty?(%Date.Range{}), do: false
  end

  defimpl Inspect do
    def inspect(%Date.Range{first: first, last: last, step: 1}, _) do
      "#DateRange<" <> inspect(first) <> ", " <> inspect(last) <> ">"
    end

    def inspect(%Date.Range{first: first, last: last, step: step}, _) do
      "#DateRange<" <> inspect(first) <> ", " <> inspect(last) <> ", #{step}>"
    end
  end
end
