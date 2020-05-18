namespace :loomio do
  task generate_test_error: :environment do
    raise "this is a generated test error"
  end

  task :version do
    puts Loomio::Version.current
  end

  task generate_static_error_pages: :environment do
    [400, 404, 410, 417, 422, 429, 500].each do |code|
      File.open("public/#{code}.html", "w") do |f|
        f << "<!-- This file is automatically generated by rake loomio:generate_static_error_pages -->\n"
        f << "<!-- Don't make changes here; they will be overwritten. -->\n"
        f << ApplicationController.new.render_to_string(
          template: "errors/#{code}",
          layout: "basic"
        )
      end
    end
  end

  task hourly_tasks: :environment do
    PollService.delay.expire_lapsed_polls
    PollService.delay.publish_closing_soon

    if ENV['EMAIL_CATCH_UP_WEEKLY']
      SendWeeklyCatchUpEmailWorker.perform_async
    else
      SendDailyCatchUpEmailWorker.perform_async
    end

    AnnouncementService.delay.resend_pending_invitations
    LocateUsersAndGroupsWorker.perform_async
    if (Time.now.hour == 0)
      UsageReportService.send
      ExamplePollService.delay.cleanup
      LoginToken.where("created_at < ?", 24.hours.ago).delete_all
    end
  end

  task generate_error: :environment do
    raise "this is an exception to test exception handling"
  end

  task notify_clients_of_update: :environment do
    MessageChannelService.publish_data({ version: Loomio::Version.current }, to: GlobalMessageChannel.instance)
  end

  task update_subscription_members_counts: :environment do
    # run only once a month
    if Date.today.day == 1
      SubscriptionService.delay.update_changed_members_counts(['active-monthly', 'active-annual', 'active-community-annual']) 
    end
    # run only once a week on wednesday
    if Date.today.wday == 3
      SubscriptionService.delay.update_changed_members_counts(['pp-basic-annual', 'pp-pro-annual', 'pp-community-annual'])
    end
    # run daily
    SubscriptionService.delay.update_changed_members_counts(['pp-basic-monthly', 'pp-pro-monthly'])
  end

  task refresh_expiring_chargify_management_links: :environment do
    # run this once a week
    if Date.today.sunday?
      SubscriptionService.delay.refresh_expiring_management_links
    end
  end

  task populate_chargify_management_links: :environment do
    if Date.today.sunday?
      SubscriptionService.delay.populate_management_links
    end
  end

end
