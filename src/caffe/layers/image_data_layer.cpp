#include <opencv2/core/core.hpp>

#include <fstream>  // NOLINT(readability/streams)
#include <iostream>  // NOLINT(readability/streams)
#include <string>
#include <utility>
#include <vector>

#include "caffe/data_transformer.hpp"
#include "caffe/layers/base_data_layer.hpp"
#include "caffe/layers/image_data_layer.hpp"
#include "caffe/util/benchmark.hpp"
#include "caffe/util/io.hpp"
#include "caffe/util/math_functions.hpp"
#include "caffe/util/rng.hpp"

namespace caffe {

template <typename Ftype, typename Btype>
ImageDataLayer<Ftype, Btype>::~ImageDataLayer<Ftype, Btype>() {
  if (layer_inititialized_flag_.is_set()) {
    this->StopInternalThread();
  }
}

template <typename Ftype, typename Btype>
void ImageDataLayer<Ftype, Btype>::DataLayerSetUp(const vector<Blob*>& bottom,
      const vector<Blob*>& top) {
  const int new_height = this->layer_param_.image_data_param().new_height();
  const int new_width  = this->layer_param_.image_data_param().new_width();
  const int short_side = this->layer_param_.image_data_param().short_side();
  const int crop = this->layer_param_.transform_param().crop_size();
  const bool is_color  = this->layer_param_.image_data_param().is_color();
  string root_folder = this->layer_param_.image_data_param().root_folder();

  CHECK((new_height == 0 && new_width == 0) ||
      (new_height > 0 && new_width > 0)) << "Current implementation requires "
      "new_height and new_width to be set at the same time.";
  // Read the file with filenames and labels
  const string& source = this->layer_param_.image_data_param().source();
  LOG(INFO) << "Opening file " << source;
  std::ifstream infile(source.c_str());
  string filename;
  int label;
  while (infile >> filename >> label) {
    lines_.push_back(std::make_pair(filename, label));
  }

  if (this->layer_param_.image_data_param().shuffle()) {
    // randomly shuffle data
    LOG(INFO) << "Shuffling data";
    prefetch_rng_.reset(new Caffe::RNG(caffe_rng_rand()));
    ShuffleImages();
  }
  LOG(INFO) << "A total of " << lines_.size() << " images.";

  lines_id_ = 0;
  // Check if we would need to randomly skip a few data points
  if (this->layer_param_.image_data_param().rand_skip()) {
    unsigned int skip = caffe_rng_rand() %
        this->layer_param_.image_data_param().rand_skip();
    LOG(INFO) << "Skipping first " << skip << " data points.";
    CHECK_GT(lines_.size(), skip) << "Not enough points to skip";
    lines_id_ = skip;
  }
  // Read an image, and use it to initialize the top blob.
  cv::Mat cv_img = ReadImageToCVMat(root_folder + lines_[lines_id_].first,
      new_height, new_width, is_color, short_side);
  CHECK(cv_img.data) << "Could not load " << lines_[lines_id_].first;
  // Reshape prefetch_data and top[0] according to the batch_size.
  const int batch_size = this->layer_param_.image_data_param().batch_size();
  CHECK_GT(batch_size, 0) << "Positive batch size required";
  const int crop_height = crop <= 0 ? cv_img.rows : std::min(cv_img.rows, crop);
  const int crop_width = crop <= 0 ? cv_img.cols : std::min(cv_img.cols, crop);
  vector<int> top_shape { batch_size, cv_img.channels(), crop_height, crop_width };
  top[0]->Reshape(top_shape);
  LOG(INFO) << "output data size: " << top[0]->num() << ", "
      << top[0]->channels() << ", " << top[0]->height() << ", "
      << top[0]->width();
  // label
  vector<int> label_shape(1, batch_size);
  top[1]->Reshape(label_shape);
  this->batch_transformer_->reshape(top_shape, label_shape);
  layer_inititialized_flag_.set();
}

template <typename Ftype, typename Btype>
void ImageDataLayer<Ftype, Btype>::ShuffleImages() {
  caffe::rng_t* prefetch_rng =
      static_cast<caffe::rng_t*>(prefetch_rng_->generator());
  shuffle(lines_.begin(), lines_.end(), prefetch_rng);
}

template<typename Ftype, typename Btype>
void ImageDataLayer<Ftype, Btype>::InitializePrefetch() {}

// This function is called on prefetch thread
template <typename Ftype, typename Btype>
void ImageDataLayer<Ftype, Btype>::load_batch(Batch* batch, int thread_id, size_t queue_id) {
  CPUTimer batch_timer;
  batch_timer.Start();
  double read_time = 0;
  double trans_time = 0;
  CPUTimer timer;
  CHECK(batch->data_->count());
  ImageDataParameter image_data_param = this->layer_param_.image_data_param();
  const int batch_size = image_data_param.batch_size();
  const int new_height = image_data_param.new_height();
  const int new_width = image_data_param.new_width();
  const int short_side = image_data_param.short_side();
  const int crop = this->layer_param_.transform_param().crop_size();
  const bool is_color = image_data_param.is_color();
  string root_folder = image_data_param.root_folder();

  // Reshape according to the first image of each batch
  // on single input batches allows for inputs of varying dimension.
  cv::Mat cv_img = ReadImageToCVMat(root_folder + lines_[lines_id_].first,
      new_height, new_width, is_color, short_side);
  CHECK(cv_img.data) << "Could not load " << lines_[lines_id_].first;
  const int crop_height = crop <= 0 ? cv_img.rows : std::min(cv_img.rows, crop);
  const int crop_width = crop <= 0 ? cv_img.cols : std::min(cv_img.cols, crop);
  // Infer the expected blob shape from a cv_img.
  vector<int> top_shape { batch_size, cv_img.channels(), crop_height, crop_width };
  batch->data_->Reshape(top_shape);
  vector<int> label_shape(1, batch_size);
  batch->label_->Reshape(label_shape);

  Ftype* prefetch_data = batch->data_->mutable_cpu_data<Ftype>();
  Ftype* prefetch_label = batch->label_->mutable_cpu_data<Ftype>();
  Packing packing = NHWC;

  // datum scales
  const int lines_size = lines_.size();
  const size_t buf_len = batch->data_->offset(1);
  for (int item_id = 0; item_id < batch_size; ++item_id) {
    // get a blob
    timer.Start();
    CHECK_GT(lines_size, lines_id_);
    cv::Mat cv_img = ReadImageToCVMat(root_folder + lines_[lines_id_].first,
        new_height, new_width, is_color, short_side);
    CHECK(cv_img.data) << "Could not load " << lines_[lines_id_].first;
    read_time += timer.MicroSeconds();
    timer.Start();
    // Apply transformations (mirror, crop...) to the image
    int offset = batch->data_->offset(item_id);

#if defined(USE_CUDNN)
    this->dt(0)->Transform(cv_img, prefetch_data + offset, buf_len, false);
#else
    vector<Btype> tmp(top_shape[1] * top_shape[2] * top_shape[3]);
    CHECK_EQ(buf_len, tmp.size());
    this->dt(0)->Transform(cv_img, prefetch_data + offset, buf_len, false);
    hwc2chw(top_shape[1], top_shape[3], top_shape[2], tmp.data(), prefetch_data + offset);
    packing = NCHW;
#endif
    trans_time += timer.MicroSeconds();
    prefetch_label[item_id] = lines_[lines_id_].second;
    // go to the next iter
    lines_id_++;
    if (lines_id_ >= lines_size) {
      // We have reached the end. Restart from the first.
      DLOG(INFO) << this->print_current_device() << "Restarting data prefetching from start.";
      lines_id_ = 0;
      if (this->layer_param_.image_data_param().shuffle()) {
        ShuffleImages();
      }
    }
  }
  batch_timer.Stop();
  DLOG(INFO) << this->print_current_device()
             << "Prefetch batch: " << batch_timer.MilliSeconds() << " ms.";
  DLOG(INFO) << this->print_current_device()
             << "     Read time: " << read_time / 1000 << " ms.";
  DLOG(INFO) << this->print_current_device()
             << "Transform time: " << trans_time / 1000 << " ms.";

  batch->set_data_packing(packing);
  batch->set_id(this->batch_id(thread_id));
}

INSTANTIATE_CLASS_CPU_FB(ImageDataLayer);

}  // namespace caffe
