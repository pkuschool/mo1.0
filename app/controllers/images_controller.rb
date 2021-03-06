require 'digest'
require 'base64'
require 'qiniu'
class ImagesController < ApplicationController
  before_action :set_image, only: [:show, :edit, :update, :destroy]

  # GET /images
  # GET /images.json
  def index
    @images = Image.all
    render :json => @images.collect { |p| p.to_jq_upload }.to_json
  end

  # GET /images/1
  # GET /images/1.json
  
  def show
    @secret = Digest::MD5.hexdigest(Digest::SHA1.hexdigest(Base64::encode64(Rails.application.secrets.angular_secret)))
    @user = User.where("id = ?", @image.user_id.to_i).last
    @element = @image
    @image.score.viewer.increment unless @user == current_user
  end

  # GET /images/new
  def new
    @key = Digest::MD5.hexdigest(Digest::SHA1.hexdigest(Base64::encode64(Time.now.to_s + rand.to_s)))
    bucket = "mosite"
    put_policy = Qiniu::Auth::PutPolicy.new(
      'mosite'
      )
    uptoken = Qiniu::Auth.generate_uptoken(put_policy)
    render json: {uptoken: uptoken }
  end

  # GET /images/1/edit
  def edit
  end

  # POST /images
  # POST /images.json
  def create
    @image = Image.new
    @image.file = params["image"]["file"].first
    if @image.save
      respond_to do |format|
        format.html {  
          render :json => [@image.to_jq_upload].to_json, 
          :content_type => 'text/html',
          :layout => false
        }
        format.json {  
          render :json => [@image.to_jq_upload].to_json           
        }
      end
    else 
      render :json => [{:error => "custom_failure"}], :status => 304
    end
  end

  # PATCH/PUT /images/1
  # PATCH/PUT /images/1.json
  def update
    respond_to do |format|
      if @image.update(image_params)
        format.html { redirect_to @image, notice: 'Image was successfully updated.' }
        format.json { render :show, status: :ok, location: @image }
      else
        format.html { render :edit }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /images/qiniu/callback
  def qiniu_callback
    begin
      @user = User.where(:id => params[:user]).first

      @image = @user.images.new(
                                    :file         =>  params[:url],
                                    :exif           =>  {},
                                  )
      @image.camera = params[:exif].model if params[:exif].model
      @image.aperture = params[:exif].f_number if params[:exif].f_number
      @image.iso = params[:exif].iso if params[:exif].iso
      @image.focal_length = params[:exif].focal_length if params[:exif].focal_length
      @image.width = params[:width] if params[:width]
      @image.height = params[:height] if params[:height]
      @image.token_at = params[:exif].taken_at if params[:exif].taken_at
      @image.exposure_time = params[:exif].exposure_time if params[:exif].exposure_time
      @image.size = params[:size] if params[:size]
      @image.color_space = params[:color_space] if params[:color_space]  

      if @image.save
        render :json => {:success => true, :files => [{:image => @image.file, :name => @image.title, :url => image_url(@image)}]}
      else
        raise Exception
      end
    rescue Exception => e
      render :json => {:success => false, :message => "上传失败!?"}
    end
  end


  # DELETE /images/1
  # DELETE /images/1.json
  def destroy
    @image.destroy
    respond_to do |format|
      #format.html { redirect_to images_url, notice: 'Image was successfully destroyed.' }
      format.json json: true
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_image
      @image = Image.find(params[:id])
      @element = @image
      $element = @music #隐患，用户不能同时对两个东西做评论，那样全局变量会错乱
      @secret = Digest::MD5.hexdigest(Digest::SHA1.hexdigest(Base64::encode64(Rails.application.secrets.angular_secret)))
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def image_params
      params.require(:image).permit(:file, :public, :title, :description, :exif)
    end

    def upload_image_params
      params[:image].permit(:file)
    end
end
