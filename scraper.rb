# frozen_string_literal: true

require 'dotenv'
Dotenv.load
require_relative 'lib/runners'

Jacaranda.run(ARGV) if $PROGRAM_NAME == __FILE__
