# frozen_string_literal: true

require 'scraperwiki'
require 'rest-client'
require 'optparse'
require 'pathname'

runners = Pathname.new(__FILE__).parent.join('runners').join('*.rb')
base = Pathname.glob(runners).map(&:to_s).find { |r| r =~ /base_runner/ }
require(base)
Pathname.glob(runners).map(&:to_s).each { |runner| require(runner) }

# Wrapper for all runners
module Jacaranda
  def self.run(args)
    parse(args)
    announce
    runners.each(&:run)
  end

  # rubocop:disable Metrics/MethodLength
  def self.parse(args)
    @whitelist = []
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
      opts.on('-r', '--runners=RUNNER[,<RUNNER>,...]', 'Runners to execute') do |r|
        @whitelist = r.split(',')
      end
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end
    opt_parser.parse!(args)
  end
  # rubocop:enable Metrics/MethodLength

  def self.runners
    @whitelist ||= []
    candidates = self::BaseRunner.descendants
    candidates.select! { |c| @whitelist.find { |w| c.to_s =~ /#{w}/i } } unless @whitelist.empty?
    candidates.sort_by { |c| c.to_s.split('::').first }
  end

  def self.announce
    puts 'These are the runners we will execute:'
    puts
    puts runners.map { |r| r.to_s.split('::').first }.join("\n")
    puts
    sleep(2)
  end
end
