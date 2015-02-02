class TipSmallImageUploader < CarrierWave::Uploader::Base

  include CarrierWave::RMagick

  storage :hes_cloud

  def store_dir
    "tips/"
  end

  # Create different versions of your uploaded files:
  version :thumbnail do
    process :resize_to_fit => [40, 40]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(jpg jpeg gif png)
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  def filename
    "tip-small-image-#{Time.now.to_i}.png" if original_filename
  end

  def default_url
    "/images/tips/small_image_" + [version_name, "default.png"].compact.join('_')
  end

end