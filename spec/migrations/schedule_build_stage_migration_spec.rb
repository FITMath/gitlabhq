require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20180212101928_schedule_build_stage_migration')

describe ScheduleBuildStageMigration, :migration do
  let(:projects) { table(:projects) }
  let(:pipelines) { table(:ci_pipelines) }
  let(:stages) { table(:ci_stages) }
  let(:jobs) { table(:ci_builds) }

  before do
    stub_const("#{described_class}::BATCH", 1)

    ##
    # Dependencies
    #
    projects.create!(id: 123, name: 'gitlab', path: 'gitlab-ce')
    pipelines.create!(id: 1, project_id: 123, ref: 'master', sha: 'adf43c3a')
    stages.create!(id: 1, project_id: 123, pipeline_id: 1, name: 'test')

    ##
    # CI/CD jobs
    #
    jobs.create!(id: 11, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 206, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 3413, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 4109, commit_id: 1, project_id: 123, stage_id: 1)
  end

  it 'schedules delayed background migrations in batches in bulk' do
    Sidekiq::Testing.fake! do
      Timecop.freeze do
        migrate!

        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(1.minute, 11)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(2.minutes, 206)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(3.minutes, 3413)
        expect(BackgroundMigrationWorker.jobs.size).to eq 3
      end
    end
  end
end
