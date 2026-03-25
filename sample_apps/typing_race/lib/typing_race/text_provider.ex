defmodule TypingRace.TextProvider do
  @texts [
    "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump. The five boxing wizards jump quickly at dawn.",
    "Programming is the art of telling another human being what one wants the computer to do. The best error message is the one that never shows up. Code is like humor. When you have to explain it, it is bad.",
    "In the middle of difficulty lies opportunity. The only way to do great work is to love what you do. Innovation distinguishes between a leader and a follower. Stay hungry, stay foolish and never stop learning.",
    "Elixir is a dynamic, functional language designed for building scalable and maintainable applications. It leverages the Erlang virtual machine, known for running low-latency, distributed and fault-tolerant systems.",
    "The best time to plant a tree was twenty years ago. The second best time is now. Success is not final, failure is not fatal. It is the courage to continue that counts. Keep moving forward always.",
    "Software engineering is what happens to programming when you add time and other programmers. Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
    "The mountains are calling and I must go. In every walk with nature one receives far more than they seek. The clearest way into the universe is through a forest wilderness. Look deep into nature.",
    "Distributed systems are hard because the network is unreliable, clocks are approximate, and failures are partial. The Erlang virtual machine was designed from the ground up to handle all of these challenges gracefully.",
    "A journey of a thousand miles begins with a single step. Do not go where the path may lead, go instead where there is no path and leave a trail. The future belongs to those who believe in beauty.",
    "Concurrency is not parallelism. Concurrency is about dealing with lots of things at once. Parallelism is about doing lots of things at once. Processes in the BEAM virtual machine make both easy and safe."
  ]

  def random_text do
    Enum.random(@texts)
  end

  def texts, do: @texts
end
