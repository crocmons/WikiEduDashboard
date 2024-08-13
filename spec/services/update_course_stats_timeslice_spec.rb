# frozen_string_literal: true

require 'rails_helper'

describe UpdateCourseStatsTimeslice do
  let(:course) { create(:course, start: '2018-11-24', end: '2018-11-30', flags:) }
  let(:enwiki) { Wiki.get_or_create(language: 'en', project: 'wikipedia') }
  let(:wikidata) { Wiki.get_or_create(language: nil, project: 'wikidata') }
  let(:subject) { described_class.new(course) }
  let(:flags) { nil }
  let(:user) { create(:user, username: 'Ragesoss') }

  context 'when debugging is not enabled' do
    it 'posts no Sentry logs' do
      expect(Sentry).not_to receive(:capture_message)
      subject
    end
  end

  context 'when :debug_updates flag is set' do
    let(:flags) { { debug_updates: true } }

    it 'posts debug info to Sentry' do
      expect(Sentry).to receive(:capture_message).at_least(6).times.and_call_original
      subject
    end
  end

  context 'when there are revisions' do
    before do
      stub_wiki_validation
      travel_to Date.new(2018, 12, 1)
      course.campaigns << Campaign.first
      course.wikis << Wiki.get_or_create(language: nil, project: 'wikidata')
      JoinCourse.new(course:, user:, role: 0)
      # Create course wiki timeslices manually for wikidata
      TimesliceManager.new(course).create_timeslices_for_new_course_wiki_records([wikidata])
    end

    it 'imports average views of edited articles' do
      VCR.use_cassette 'course_update' do
        subject
      end

      # 2 en.wiki articles
      expect(course.articles.where(wiki: enwiki).count).to eq(2)
      # 13 wikidata articles, but one is for Property namespace (120)
      expect(course.articles.where(wiki: wikidata).count).to eq(12)
      expect(course.articles.where(wiki: enwiki).last.average_views).to be > 200
    end

    it 'updates article course and article course timeslices caches' do
      VCR.use_cassette 'course_update' do
        subject
      end

      # Check caches for mw_page_id 6901525
      article = Article.find_by(mw_page_id: 6901525)
      # The article course exists
      article_course = ArticlesCourses.find_by(article_id: article.id)
      # The article course caches were updated
      expect(article_course.character_sum).to eq(427)
      expect(article_course.references_count).to eq(-2)
      expect(article_course.user_ids).to eq([user.id])
      expect(article_course.view_count).to eq(3)

      # Article course timeslice record was created for mw_page_id 6901525
      # timeslices from 2018-11-24 to 2018-11-30 were created
      expect(article_course.article_course_timeslices.count).to eq(10)
      expect(article_course.article_course_timeslices.fourth.start).to eq('2018-11-24')
      expect(article_course.article_course_timeslices.last.start).to eq('2018-11-30')
      # Article course timeslices caches were updated
      expect(article_course.article_course_timeslices.fourth.character_sum).to eq(427)
      expect(article_course.article_course_timeslices.fourth.references_count).to eq(-2)
      expect(article_course.article_course_timeslices.fourth.user_ids).to eq([user.id])
    end

    it 'updates course user and course user wiki timeslices caches' do
      VCR.use_cassette 'course_update' do
        subject
      end

      # Check caches for course user
      course_user = CoursesUsers.find_by(course:, user:)
      # The course user caches were updated
      # All the revisions were done in mainspace = 0,
      # except for one revision in mainspace = 120, which is ommited
      expect(course_user.character_sum_ms).to eq(7991)
      expect(course_user.character_sum_us).to eq(0)
      expect(course_user.character_sum_draft).to eq(0)
      # expect(course_user.references_count).to eq(-2)
      expect(course_user.revision_count).to eq(29)
      expect(course_user.recent_revisions).to eq(0)
      expect(course_user.total_uploads).to eq(0)

      # At least two course user timeslice records were updated

      # Course user timeslices caches were updated
      # For enwiki
      timeslice = course_user.course_user_wiki_timeslices.where(wiki: enwiki,
                                                                start: '2018-11-24').first
      expect(timeslice.character_sum_ms).to eq(46)
      expect(timeslice.character_sum_us).to eq(0)
      expect(timeslice.character_sum_draft).to eq(0)
      expect(timeslice.revision_count).to eq(1)
      expect(timeslice.references_count).to eq(0)

      # For wikidata
      timeslice = course_user.course_user_wiki_timeslices.where(wiki: wikidata,
                                                                start: '2018-11-24').first
      expect(timeslice.character_sum_ms).to eq(7867)
      expect(timeslice.character_sum_us).to eq(0)
      expect(timeslice.character_sum_draft).to eq(0)
      expect(timeslice.revision_count).to eq(27)
      expect(timeslice.references_count).to eq(-2)
    end

    it 'updates course and course wiki timeslices caches' do
      VCR.use_cassette 'course_update' do
        subject
      end

      # Check caches for course
      # Course caches were updated
      expect(course.character_sum).to eq(7991)
      expect(course.references_count).to eq(-2)
      expect(course.revision_count).to eq(29)
      # TODO: view_sum should be 918. See issue #5911
      expect(course.view_sum).to eq(912)
      expect(course.user_count).to eq(1)
      expect(course.trained_count).to eq(1)
      # TODO: update recent_revision_count
      expect(course.recent_revision_count).to eq(0)
      expect(course.article_count).to eq(14)
      expect(course.new_article_count).to eq(0)
      expect(course.upload_count).to eq(0)
      expect(course.uploads_in_use_count).to eq(0)
      expect(course.upload_usages_count).to eq(0)

      # 14 course wiki timeslices records were created: 7 for enwiki and 7 for wikidata
      expect(course.course_wiki_timeslices.count).to eq(20)

      # Course user timeslices caches were updated
      # For enwiki
      timeslice = course.course_wiki_timeslices.where(wiki: enwiki,
                                                      start: '2018-11-29').first
      expect(timeslice.character_sum).to eq(78)
      expect(timeslice.references_count).to eq(0)
      expect(timeslice.revision_count).to eq(1)
      expect(timeslice.upload_count).to eq(0)
      expect(timeslice.uploads_in_use_count).to eq(0)
      expect(timeslice.upload_usages_count).to eq(0)
      expect(timeslice.last_mw_rev_datetime).to eq('20181129180841'.to_datetime)

      # For wikidata
      timeslice = course.course_wiki_timeslices.where(wiki: wikidata,
                                                      start: '2018-11-24').first
      expect(timeslice.character_sum).to eq(7867)
      expect(timeslice.references_count).to eq(-2)
      expect(timeslice.revision_count).to eq(27)
      expect(timeslice.upload_count).to eq(0)
      expect(timeslice.uploads_in_use_count).to eq(0)
      expect(timeslice.upload_usages_count).to eq(0)
      expect(timeslice.last_mw_rev_datetime).to eq('20181124045740'.to_datetime)
    end

    it 'rolls back the updates if something goes wrong' do
      allow(Sentry).to receive(:capture_message)
      # Stub out update_all_caches_from_timeslices to raise an error
      allow(CoursesUsers).to receive(:update_all_caches_from_timeslices)
        .and_raise(StandardError, 'Simulated failure')

      VCR.use_cassette 'course_update' do
        subject
      end

      expect(Sentry).to have_received(:capture_message)

      # Check caches for mw_page_id 6901525
      article = Article.find_by(mw_page_id: 6901525)
      # The article course exists
      article_course = ArticlesCourses.find_by(article_id: article.id)
      # The article course caches weren't updated
      expect(article_course.character_sum).to eq(0)
      # last_mw_rev_datetime wasn't updated
      timeslice = course.course_wiki_timeslices.where(wiki: enwiki,
                                                      start: '2018-11-29').first

      expect(timeslice.last_mw_rev_datetime).to be_nil
    end
  end

  context 'sentry course update error tracking' do
    let(:flags) { { debug_updates: true } }
    let(:user) { create(:user, username: 'Ragesoss') }

    before do
      travel_to Date.new(2018, 11, 28)
      course.campaigns << Campaign.first
      JoinCourse.new(course:, user:, role: 0)
    end

    it 'tracks update errors properly in Replica' do
      allow(Sentry).to receive(:capture_exception)

      # Raising errors only in Replica
      stub_request(:any, %r{https://replica-revision-tools.wmcloud.org/.*}).to_raise(Errno::ECONNREFUSED)
      VCR.use_cassette 'course_update/replica' do
        subject
      end
      sentry_tag_uuid = subject.sentry_tag_uuid
      expect(course.flags['update_logs'][1]['error_count']).to eq 1
      expect(course.flags['update_logs'][1]['sentry_tag_uuid']).to eq sentry_tag_uuid

      # Checking whether Sentry receives correct error and tags as arguments
      expect(Sentry).to have_received(:capture_exception).once.with(Errno::ECONNREFUSED, anything)
      expect(Sentry).to have_received(:capture_exception)
        .once.with anything, hash_including(tags: { update_service_id: sentry_tag_uuid,
                                                    course: course.slug })
    end

    it 'tracks update errors properly in LiftWing' do
      allow(Sentry).to receive(:capture_exception)

      # Raising errors only in LiftWing
      stub_request(:any, %r{https://api.wikimedia.org/service/lw.*}).to_raise(Faraday::ConnectionFailed)
      VCR.use_cassette 'course_update/lift_wing_api' do
        subject
      end
      sentry_tag_uuid = subject.sentry_tag_uuid
      expect(course.flags['update_logs'][1]['error_count']).to eq 2
      expect(course.flags['update_logs'][1]['sentry_tag_uuid']).to eq sentry_tag_uuid

      # Checking whether Sentry receives correct error and tags as arguments
      expect(Sentry).to have_received(:capture_exception)
        .exactly(2).times.with(Faraday::ConnectionFailed, anything)
      expect(Sentry).to have_received(:capture_exception)
        .exactly(2).times.with anything, hash_including(tags: { update_service_id: sentry_tag_uuid,
                                                                course: course.slug })
    end

    it 'tracks update errors properly in WikiApi' do
      allow(Sentry).to receive(:capture_exception)
      allow_any_instance_of(described_class).to receive(:update_article_status).and_return(nil)

      # Raising errors only in WikiApi
      allow_any_instance_of(MediawikiApi::Client).to receive(:send)
        .and_raise(MediawikiApi::ApiError)
      VCR.use_cassette 'course_update/wiki_api' do
        subject
      end
      sentry_tag_uuid = subject.sentry_tag_uuid
      expect(course.flags['update_logs'][1]['error_count']).to be_positive
      expect(course.flags['update_logs'][1]['sentry_tag_uuid']).to eq sentry_tag_uuid

      # Checking whether Sentry receives correct error and tags as arguments
      expect(Sentry).to have_received(:capture_exception)
        .at_least(2).times.with(MediawikiApi::ApiError, anything)
      expect(Sentry).to have_received(:capture_exception)
        .at_least(2).times.with anything, hash_including(tags: { update_service_id: sentry_tag_uuid,
                                                                course: course.slug })
    end

    context 'when a Programs & Events Dashboard course has a potentially long update time' do
      let(:course) do
        create(:course, start: 1.day.ago, end: 1.year.from_now,
                        flags: { longest_update: 1.hour.to_i })
      end

      before do
        allow(Features).to receive(:wiki_ed?).and_return(false)
      end

      it 'skips article status updates' do
        expect_any_instance_of(described_class).not_to receive(:update_article_status)
        subject
      end
    end
  end
end