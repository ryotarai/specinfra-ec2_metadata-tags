require 'specinfra/ec2_metadata/tags/version'
require 'aws-sdk'

module Specinfra
  class Ec2Metadata
    class Tags
      def initialize(host_inventory)
        @host_inventory = host_inventory
      end

      def get
        begin
          get_by_describe_tags
        rescue Aws::EC2::Errors::RequestLimitExceeded
          get_by_describe_instances
        end
      end

      private
      def region
        @host_inventory['ec2']['placement']['availability-zone'].gsub(/[a-z]$/, '')
      end

      def get_by_describe_tags
        page = client.describe_tags(
          :filters => [{
            :name   => 'resource-id',
            :values => [ @host_inventory['ec2']['instance-id'] ],
          }]
        )
        tags = {}
        page.each do |p|
          page.tags.each do |t|
            tags[t['key']] = t['value']
          end
        end
        tags
      end

      def get_by_describe_instances
        resp = client.describe_instances(
          :instance_ids => [@host_inventory['ec2']['instance-id']],
        )
        tags = {}
        instance = resp.reservations.first.instances.first
        instance.tags.each do |t|
          tags[t.key] = t.value
        end
        tags
      end

      def client
        return @client if @client

        retry_limit = ENV.fetch('SPECINFRA_EC2_RETRY_LIMIT', 3).to_i
        @client = Aws::EC2::Client.new(
          :region => region,
          :retry_limit => retry_limit,
        )
      end
    end
  end
end
