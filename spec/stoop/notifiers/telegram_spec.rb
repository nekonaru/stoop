# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'stoop/notifiers/telegram'

RSpec.describe Stoop::Notifiers::Telegram do
  subject(:telegram) { described_class.new(bot_token: 'test-token', chat_id: '12345') }

  it 'delivers a message to the Bot API' do
    stub = stub_request(:post, 'https://api.telegram.org/bottest-token/sendMessage')
           .with do |request|
             body = JSON.parse(request.body)
             body['chat_id'] == '12345' && body['text'] == 'hello'
           end
           .to_return(status: 200, body: '{"ok":true}', headers: { 'Content-Type' => 'application/json' })

    expect(telegram.deliver('hello')).to be(true)
    expect(stub).to have_been_requested
  end

  it 'raises NotifierError with the API description on failure' do
    stub_request(:post, 'https://api.telegram.org/bottest-token/sendMessage')
      .to_return(status: 401, body: '{"ok":false,"description":"Unauthorized"}',
                 headers: { 'Content-Type' => 'application/json' })

    expect { telegram.deliver('hello') }.to raise_error(Stoop::Notifiers::NotifierError, /Unauthorized/)
  end

  it 'never leaks the token in the error message' do
    stub_request(:post, 'https://api.telegram.org/bottest-token/sendMessage').to_timeout

    expect { telegram.deliver('hello') }
      .to raise_error(Stoop::Notifiers::NotifierError) { |e| expect(e.message).not_to include('test-token') }
  end

  it 'raises a clear error when the token is missing' do
    expect { described_class.new(bot_token: nil, chat_id: nil) }
      .to raise_error(Stoop::Notifiers::NotifierError, /TELEGRAM_BOT_TOKEN/)
  end

  it 'raises a clear error when the chat id is missing' do
    expect { described_class.new(bot_token: 'token', chat_id: nil) }
      .to raise_error(Stoop::Notifiers::NotifierError, /TELEGRAM_CHAT_ID/)
  end
end
