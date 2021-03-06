class ApplePushNotificationsController < ApplicationController

  skip_before_action :verify_authenticity_token
  skip_before_action :authorize
  before_action :find_user, only: [:update, :delete]

  def create
    user_info = JSON.parse(request.body.read)
    user_id = verify_push_token(user_info['authentication_token'])
    @user = User.find(user_id)

    package = build_grocer_package(user_info['authentication_token'])
    send_data package.buffer, type: :zip
  end

  def update
    @user.apple_push_notification_device_token = params[:device_token]
    @user.save
    render nothing: true
  end

  def delete
    @user.apple_push_notification_device_token = nil
    @user.save
    render nothing: true
  end

  def log
    Honeybadger.notify(
      error_class: "Apple Push Notification",
      error_message: "Apple Push Notification Failure",
      parameters: params
    )
    render nothing: true
  end

  private

  def find_user
    # Authorization header should look like:
    # Authorization: ApplePushNotifications AUTH_TOKEN
    name, authentication_token = request.authorization.split(' ')
    user_id = nil
    if name == 'ApplePushNotifications'
      user_id = verify_push_token(authentication_token)
    end
    @user = User.find(user_id)
  end

  def build_grocer_package(user_token)
    p12 = OpenSSL::PKCS12.new(File.read(ENV['APPLE_PUSH_CERT']))
    package = Grocer::Pushpackager::Package.new({
      websiteName: 'Feedbin',
      websitePushID: ENV['APPLE_PUSH_WEBSITE_ID'],
      allowedDomains: [ENV['PUSH_URL']],
      urlFormatString: "#{ENV['PUSH_URL']}/entries/%@/push_view?user=%@",
      authenticationToken: user_token,
      webServiceURL: "#{ENV['PUSH_URL']}/apple_push_notifications",
      certificate: p12.certificate,
      key: p12.key,
      iconSet: {
        :'16x16'      => push_icon_path('16x16'),
        :'16x16@2x'   => push_icon_path('16x16@2x'),
        :'32x32'      => push_icon_path('32x32'),
        :'32x32@2x'   => push_icon_path('32x32@2x'),
        :'128x128'    => push_icon_path('128x128'),
        :'128x128@2x' => push_icon_path('128x128@2x')
      }
    })
  end

  def push_icon_path(size)
    File.open(Rails.application.assets["push-iconset/#{size}.png"].pathname)
  end

end
