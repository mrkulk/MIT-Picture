function ftrs = get_cnn_ftrs(net, im, layer_id)
    im_ = single(im);
    im_ = imresize(im_, net.normalization.imageSize(1:2));
    im_ = im_ - net.normalization.averageImage;

    res = vl_simplenn(net,im_);

    ftrs = res(layer_id).x(:);
end

