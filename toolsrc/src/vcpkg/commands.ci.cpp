#include "pch.h"

#include <vcpkg/base/files.h>
#include <vcpkg/base/system.h>
#include <vcpkg/base/util.h>
#include <vcpkg/build.h>
#include <vcpkg/commands.h>
#include <vcpkg/dependencies.h>
#include <vcpkg/help.h>
#include <vcpkg/input.h>
#include <vcpkg/install.h>
#include <vcpkg/vcpkglib.h>

namespace vcpkg::Commands::CI
{
    using Build::BuildResult;
    using Dependencies::InstallPlanAction;
    using Dependencies::InstallPlanType;

    static Install::InstallSummary run_ci_on_triplet(const Triplet& triplet,
                                                     const VcpkgPaths& paths,
                                                     const std::vector<std::string>& ports,
                                                     const std::set<std::string>& exclusions_set)
    {
        Input::check_triplet(triplet, paths);

        const std::vector<PackageSpec> specs = PackageSpec::to_package_specs(ports, triplet);

        StatusParagraphs status_db = database_load_check(paths);
        const auto& paths_port_file = Dependencies::PathsPortFile(paths);
        std::vector<InstallPlanAction> install_plan =
            Dependencies::create_install_plan(paths_port_file, specs, status_db);

        for (InstallPlanAction& plan : install_plan)
        {
            if (Util::Sets::contains(exclusions_set, plan.spec.name()))
            {
                plan.plan_type = InstallPlanType::EXCLUDED;
            }
        }

        Checks::check_exit(VCPKG_LINE_INFO, !install_plan.empty(), "Install plan cannot be empty");

        const Build::BuildPackageOptions install_plan_options = {Build::UseHeadVersion::NO, Build::AllowDownloads::YES};

        const std::vector<Dependencies::AnyAction> action_plan =
            Util::fmap(install_plan, [](InstallPlanAction& install_action) {
                return Dependencies::AnyAction(std::move(install_action));
            });

        return Install::perform(action_plan, install_plan_options, Install::KeepGoing::YES, paths, status_db);
    }

    struct TripletAndSummary
    {
        Triplet triplet;
        Install::InstallSummary summary;
    };

    void perform_and_exit(const VcpkgCmdArguments& args, const VcpkgPaths& paths, const Triplet& default_triplet)
    {
        static const std::string OPTION_EXCLUDE = "--exclude";

        static const std::string EXAMPLE = Help::create_example_string("ci x64-windows");

        const ParsedArguments options = args.check_and_get_optional_command_arguments({}, {OPTION_EXCLUDE});
        const std::vector<std::string> exclusions = Strings::split(options.settings.at(OPTION_EXCLUDE), ",");
        const std::set<std::string> exclusions_set(exclusions.cbegin(), exclusions.cend());

        std::vector<Triplet> triplets;
        for (const std::string& triplet : args.command_arguments)
        {
            triplets.push_back(Triplet::from_canonical_name(triplet));
        }

        if (triplets.empty())
        {
            triplets.push_back(default_triplet);
        }

        const std::vector<std::string> ports = Install::get_all_port_names(paths);
        std::vector<TripletAndSummary> results;
        for (const Triplet& triplet : triplets)
        {
            Install::InstallSummary summary = run_ci_on_triplet(triplet, paths, ports, exclusions_set);
            results.push_back({triplet, std::move(summary)});
        }

        for (auto&& result : results)
        {
            System::println("\nTriplet: %s", result.triplet);
            System::println("Total elapsed time: %s", result.summary.total_elapsed_time);
            result.summary.print();
        }

        Checks::exit_success(VCPKG_LINE_INFO);
    }
}
