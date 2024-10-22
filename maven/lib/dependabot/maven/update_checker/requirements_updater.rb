# typed: strict
# frozen_string_literal: true

#######################################################
# For more details on Maven version constraints, see: #
# https://maven.apache.org/pom.html#Dependencies      #
#######################################################

require "dependabot/requirements_updater/base"
require "dependabot/maven/update_checker"
require "dependabot/maven/version"
require "dependabot/maven/requirement"

module Dependabot
  module Maven
    class UpdateChecker
      class RequirementsUpdater
        extend T::Sig
        extend T::Generic

        Version = type_member { { fixed: Dependabot::Maven::Version } }
        Requirement = type_member { { fixed: Dependabot::Maven::Requirement } }

        include Dependabot::RequirementsUpdater::Base

        sig do
          params(
            requirements: T::Array[T::Hash[Symbol, T.untyped]],
            latest_version: T.nilable(T.any(Version, String)),
            source_url: String,
            properties_to_update: T::Array[String]
          ).void
        end
        def initialize(requirements:, latest_version:, source_url:,
                       properties_to_update:)
          @requirements = requirements
          @source_url = source_url
          @properties_to_update = properties_to_update
          return unless latest_version

          @latest_version = T.let(version_class.new(latest_version), Version)
        end

        sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
        def updated_requirements
          return requirements unless latest_version

          # NOTE: Order is important here. The FileUpdater needs the updated
          # requirement at index `i` to correspond to the previous requirement
          # at the same index.
          requirements.map do |req|
            next req if req.fetch(:requirement).nil?
            next req if req.fetch(:requirement).include?(",")

            property_name = req.dig(:metadata, :property_name)
            next req if property_name && !properties_to_update.include?(property_name)

            new_req = update_requirement(req[:requirement])
            req.merge(requirement: new_req, source: updated_source)
          end
        end

        private

        sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
        attr_reader :requirements

        sig { returns(T.nilable(Version)) }
        attr_reader :latest_version

        sig { returns(String) }
        attr_reader :source_url

        sig { returns(T::Array[String]) }
        attr_reader :properties_to_update

        sig { params(req_string: String).returns(String) }
        def update_requirement(req_string)
          # Since range requirements are excluded this must be exact
          update_exact_requirement(req_string)
        end

        sig { params(req_string: String).returns(String) }
        def update_exact_requirement(req_string)
          old_version = requirement_class.new(req_string)
                                         .requirements.first.last
          req_string.gsub(old_version.to_s, latest_version.to_s)
        end

        sig { override.returns(T::Class[Version]) }
        def version_class
          Maven::Version
        end

        sig { override.returns(T::Class[Requirement]) }
        def requirement_class
          Maven::Requirement
        end

        sig { returns(T::Hash[Symbol, String]) }
        def updated_source
          { type: "maven_repo", url: source_url }
        end
      end
    end
  end
end
