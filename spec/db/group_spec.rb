require File.expand_path '../../spec_helper.rb', __FILE__

describe "Group" do
  let(:group){ Gaps::DB::Group.new }
  let(:user){ Gaps::DB::User.new }
  let(:requestor){ Gaps::Requestor.new(user) }

  let(:valid_json){ JSON({category:'General'}) }
  let(:invalid_json){ "{\"invalid\":\"json\"]" }
  let(:valid_non_hash_json){ JSON(%w{general todos}) }

  let(:group_description){ "Everything under the sun." }
  let(:multiline_group_description){ "Everything under the sun.\nIt has been a real fine day indeed.\nOh yea!" }
  
  let(:valid_json_description){ "#{group_description}\n#{valid_json}" }
  let(:valid_non_hash_json_description){ "#{group_description}\n#{valid_non_hash_json}" }
  let(:valid_multiline_json_description){ "#{multiline_group_description}\n#{valid_json}" }

  let(:invalid_json_description){ "#{group_description}\n#{invalid_json}" }
  let(:invalid_json_multiline_description){ "#{multiline_group_description}\n#{invalid_json}" }

  context "#try_extracting_config_from_raw_description_string" do
    it "single line description" do
      group.description = valid_json_description
      expect(group.try_extracting_config_from_raw_description_string).to eq([group_description, valid_json])
    end

    it "multi line description" do
      group.description = valid_multiline_json_description
      expect(group.try_extracting_config_from_raw_description_string).to eq([multiline_group_description, valid_json])
    end

    it "no config in json" do
      group.description = group_description
      expect(group.try_extracting_config_from_raw_description_string).to_not be
    end

    it "returns invalid json string as is" do
      group.description = invalid_json_description
      expect(group.try_extracting_config_from_raw_description_string).to eq([group_description, invalid_json])
    end

    it "returns invalid json string as is (multi-line description)" do
      group.description = invalid_json_multiline_description
      expect(group.try_extracting_config_from_raw_description_string).to eq([multiline_group_description, invalid_json])
    end
  end

  context "#parse_config_from_description" do
    it "valid JSON hash" do
      group.description = valid_json_description
      expect(group.parse_config_from_description).to eq({"category" => "General"})
      expect(group.description).to eq(group_description)
    end
    it "valid JSON, not hash" do
      group.description = valid_non_hash_json_description
      expect(group.parse_config_from_description).to eq({})
      expect(group.description).to eq(valid_non_hash_json_description)
    end
    it "invalid category tag" do
      group.description = invalid_json_description
      expect(group.parse_config_from_description).to eq({})
      expect(group.description).to eq(invalid_json_description)
    end
  end

  context "#update_config" do
    before do
      configatron.unlock!
      configatron.populate_group_settings = false
      group.group_email = "talk@stripe.com"
    end
    it "sets category for valid category config" do
      group.description = valid_json_description
      group.update_config(user)

      expect(group.category).to eq("General")
    end

    it "guesses category using group_name for invalid category config" do
      group.description = invalid_json_description
      group.update_config(user)

      expect(group.category).to eq("talk")
    end
  end

  context "Move category" do
    before do
      # Stub Mongodb, until we want test environments and test mongodbs
      allow(MongoMapper).to receive_messages(database: double.as_null_object)

      group.category = "oldcategory"
    end

    it "persists to mongodb directly if configatron.persist_config_to_group is false" do
      configatron.persist_config_to_group = false

      expect(group).to_not receive(:update_config)
      expect(group).to_not receive(:persist_config)

      group.move_category("Misc")
    end

    it "reloads config from group description (to minimize data loss) and triggers google group update api call" do
      configatron.persist_config_to_group = true

      expect(group).to receive(:update_config)
      expect(group).to receive(:persist_config)

      group.move_category("Misc")
    end
  end
end
