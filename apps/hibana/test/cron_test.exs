defmodule Hibana.CronTest do
  use ExUnit.Case, async: true

  alias Hibana.Cron

  describe "matches?/6" do
    test "wildcard matches everything" do
      assert Cron.matches?("* * * * *", 30, 12, 15, 6, 3)
    end

    test "specific minute matches" do
      assert Cron.matches?("30 * * * *", 30, 12, 15, 6, 3)
      refute Cron.matches?("30 * * * *", 15, 12, 15, 6, 3)
    end

    test "specific hour matches" do
      assert Cron.matches?("* 12 * * *", 30, 12, 15, 6, 3)
      refute Cron.matches?("* 12 * * *", 30, 13, 15, 6, 3)
    end

    test "specific day of month matches" do
      assert Cron.matches?("* * 15 * *", 30, 12, 15, 6, 3)
      refute Cron.matches?("* * 15 * *", 30, 12, 16, 6, 3)
    end

    test "specific month matches" do
      assert Cron.matches?("* * * 6 *", 30, 12, 15, 6, 3)
      refute Cron.matches?("* * * 6 *", 30, 12, 15, 7, 3)
    end

    test "specific weekday matches" do
      assert Cron.matches?("* * * * 3", 30, 12, 15, 6, 3)
      refute Cron.matches?("* * * * 3", 30, 12, 15, 6, 4)
    end

    test "step expression */5 for minutes" do
      assert Cron.matches?("*/5 * * * *", 0, 0, 1, 1, 0)
      assert Cron.matches?("*/5 * * * *", 5, 0, 1, 1, 0)
      assert Cron.matches?("*/5 * * * *", 10, 0, 1, 1, 0)
      assert Cron.matches?("*/5 * * * *", 55, 0, 1, 1, 0)
      refute Cron.matches?("*/5 * * * *", 3, 0, 1, 1, 0)
      refute Cron.matches?("*/5 * * * *", 7, 0, 1, 1, 0)
    end

    test "step expression */2 for hours" do
      assert Cron.matches?("* */2 * * *", 0, 0, 1, 1, 0)
      assert Cron.matches?("* */2 * * *", 0, 2, 1, 1, 0)
      assert Cron.matches?("* */2 * * *", 0, 22, 1, 1, 0)
      refute Cron.matches?("* */2 * * *", 0, 1, 1, 1, 0)
    end

    test "range expression" do
      assert Cron.matches?("1-5 * * * *", 1, 0, 1, 1, 0)
      assert Cron.matches?("1-5 * * * *", 3, 0, 1, 1, 0)
      assert Cron.matches?("1-5 * * * *", 5, 0, 1, 1, 0)
      refute Cron.matches?("1-5 * * * *", 0, 0, 1, 1, 0)
      refute Cron.matches?("1-5 * * * *", 6, 0, 1, 1, 0)
    end

    test "list expression" do
      assert Cron.matches?("1,15,30 * * * *", 1, 0, 1, 1, 0)
      assert Cron.matches?("1,15,30 * * * *", 15, 0, 1, 1, 0)
      assert Cron.matches?("1,15,30 * * * *", 30, 0, 1, 1, 0)
      refute Cron.matches?("1,15,30 * * * *", 2, 0, 1, 1, 0)
    end

    test "combined: every day at midnight" do
      assert Cron.matches?("0 0 * * *", 0, 0, 15, 6, 3)
      refute Cron.matches?("0 0 * * *", 1, 0, 15, 6, 3)
      refute Cron.matches?("0 0 * * *", 0, 1, 15, 6, 3)
    end

    test "combined: weekday specific" do
      # Monday at midnight (weekday 1)
      assert Cron.matches?("0 0 * * 1", 0, 0, 1, 1, 1)
      refute Cron.matches?("0 0 * * 1", 0, 0, 1, 1, 2)
    end

    test "invalid expression returns false" do
      refute Cron.matches?("bad", 0, 0, 1, 1, 0)
    end
  end
end
