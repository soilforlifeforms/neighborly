require 'spec_helper'

describe ProjectDecorator do
  let(:project){ create(:project, summary: 'Foo Bar http://www.foo.bar <javascript>xss()</javascript>[Click here](http://click.here)') }

  describe "#time_to_go" do
    let(:project){ build(:project) }
    let(:expires_at){ Time.zone.parse("23:00:00") }
    subject{ project.time_to_go }
    before do
      project.stub(:expires_at).and_return(expires_at)
    end

    context "when there is more than 1 day to go" do
      let(:expires_at){ Time.zone.now + 2.days }
      it{ should == {:time=>2, :unit=>"days"} }
    end

    context "when there is less than 1 day to go" do
      let(:expires_at){ Time.zone.now + 13.hours }
      it{ should == {:time=>13, :unit=>"hours"} }
    end

    context "when there is less than 1 hour to go" do
      let(:expires_at){ Time.zone.now + 59.minutes }
      it{ should == {:time=>59, :unit=>"minutes"} }
    end
  end

  describe '#display_organization_type' do
    before { project.update_column :organization_type, :municipality}
    it { expect(project.reload.display_organization_type).to eq 'Municipality' }
  end

  describe "#display_expires_at" do
    subject{ project.display_expires_at }

    context "when online_date is nil" do
      let(:project){ create(:project, online_date: nil) }
      it{ should == '' }
    end

    context "when we have an online_date" do
      let(:project){ create(:project, online_date: Time.now) }
      before do
        I18n.should_receive(:l).with(project.expires_at.to_date)
      end
      it("should call I18n with date"){ subject }
    end
  end

  describe "#display_image" do
    subject{ project.display_image }

    context "when we have a video_url without thumbnail" do
      let(:project){ create(:project, uploaded_image: nil, video_thumbnail: nil) }

      it 'returns the image for "downloading in progress"' do
        expect(subject).to eql('image-placeholder-upload-in-progress.jpg')
      end
    end

    context "when we have a video_thumbnail" do
      let(:project){ create(:project, video_thumbnail: File.open("#{Rails.root}/spec/fixtures/image.png")) }
      it{ should == project.video_thumbnail.project_thumb.url }
    end

    context "when we have an uploaded_image" do
      let(:project){ create(:project, uploaded_image: File.open("#{Rails.root}/spec/fixtures/image.png"), video_thumbnail: nil) }
      it{ should == project.uploaded_image.project_thumb.url }
    end
  end

  describe "#display_address_formated" do
    subject{ project.display_address_formated }

    context "when we have all the address fields" do
      let(:project){ create(:project, location: 'Kansas City, MO', address_neighborhood: 'Downtown') }
      it{ should == "Downtown // Kansas City, MO" }
    end

    context "when we have just address_city" do
      let(:project){ create(:project, location: 'Kansas City', address_state: '') }
      it{ should == 'Kansas City' }
    end

    context "when we have just address_state" do
      let(:project){ create(:project, location: ', MO') }
      it{ should == 'MO' }
    end

    context "when we have address_city and address_state" do
      let(:project){ create(:project, location: 'Kansas City, MO') }
      it{ should == 'Kansas City, MO' }
    end
  end

  describe "#summary_html" do
    subject{ project.summary_html }
    it{ should == "<p>Foo Bar <a href=\"http://www.foo.bar\">http://www.foo.bar</a> &lt;javascript&gt;xss()&lt;/javascript&gt;<a href=\"http://click.here\">Click here</a></p>\n" }
  end

  describe "#display_status" do
    subject{ project.display_status }
    context "when online and reached goal" do
      before do
        project.stub(:state).and_return('online')
        project.stub(:reached_goal?).and_return(true)
      end
      it{ should == 'reached_goal' }
    end
    context "when online and have not reached goal yet" do
      before do
        project.stub(:state).and_return('online')
        project.stub(:reached_goal?).and_return(false)
      end
      it{ should == 'not_reached_goal' }
    end
    context "when successful" do
      before do
        project.stub(:state).and_return('successful')
      end
      it{ should == 'successful' }
    end
    context "when waiting funds" do
      before do
        project.stub(:state).and_return('waiting_funds')
      end
      it{ should == 'waiting_funds' }
    end
  end

  describe '#display_video_embed_url' do
    before do
      Sidekiq::Testing.inline!
    end

    subject{ project.display_video_embed_url }

    context 'source has a Vimeo video' do
      let(:project) { create(:project, video_url: 'http://vimeo.com/17298435') }

      before do
        project.reload
      end

      it { should == '//player.vimeo.com/video/17298435?title=0&byline=0&portrait=0&autoplay=0&color=ffffff&badge=0&modestbranding=1&showinfo=0&border=0&controls=2' }
    end

    context 'source has an Youtube video' do
      let(:project) { create(:project, video_url: "http://www.youtube.com/watch?v=Brw7bzU_t4c") }

      before do
        project.reload
      end

      it { should == '//www.youtube.com/embed/Brw7bzU_t4c?title=0&byline=0&portrait=0&autoplay=0&color=ffffff&badge=0&modestbranding=1&showinfo=0&border=0&controls=2' }
    end

    context 'source does not have a video' do
      let(:project) { create(:project, video_url: "") }

      it { should be_nil }
    end
  end

  describe 'rating description' do
    it 'returns localized string when does have rating' do
      project.rating = 0
      expected_string = I18n.t('projects.hero.rating_definitions')[0]
      expect(project.rating_description).to eql(expected_string)
    end

    it 'returns blank string when does not have rating' do
      project.rating = nil
      expect(project.rating_description).to be_empty
    end
  end

  describe 'maturity period' do
    it 'returns years of both ends of rewards' do
      create(:reward, happens_at: Date.new(2090), project: project)
      create(:reward, happens_at: Date.new(2060), project: project)
      expect(project.maturity_period).to eql('2060-2090')
    end

    it 'returns year of rewards if everything is in the same' do
      create(:reward, happens_at: Date.new(2090), project: project)
      create(:reward, happens_at: Date.new(2090), project: project)
      expect(project.maturity_period).to eql('2090')
    end

    it 'returns blank string when does not have rewards' do
      expect(project.maturity_period).to be_empty
    end
  end

  describe 'yield' do
    it 'returns yields of both ends of rewards' do
      project.rewards << build(:reward, yield: 2.24)
      project.rewards << build(:reward, yield: 3)
      expect(project.display_yield).to eql('2.24% - 3%')
    end

    it 'returns yield of rewards if everything is in the same' do
      project.rewards << build(:reward, yield: 2.24)
      project.rewards << build(:reward, yield: 2.24)
      expect(project.display_yield).to eql('2.24%')
    end

    it 'returns TBD when does not have rewards' do
      expect(project.display_yield).to match('TBD')
    end
  end
end

