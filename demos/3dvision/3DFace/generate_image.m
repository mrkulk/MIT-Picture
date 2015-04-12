function image = generate_image(model, alpha,beta, phi, elv,  mode_az,mode_ev, particle_id)
    shape  = coef2object( alpha, model.shapeMU, model.shapePC, model.shapeEV, model.segMM, model.segMB );
    tex    = coef2object( beta, model.texMU, model.texPC, model.texEV, model.segMM, model.segMB );
    
    close all;
    
    %render    
    rp     = defrp;
    rp.phi = phi;%0;
    rp.elevation = elv; %0;
    rp.dir_light.dir = [0;1;1];
    rp.dir_light.intens = 0.6*ones(3,1);
    handle = display_face(shape, tex, model.tl, rp,  mode_az,mode_ev, particle_id);
    rp.sbufsize=2000;
    
    image = hardcopy(handle, '-dzbuffer', '-r0');
    % uncomment to see
   % frame = getframe(1,[0 0 rp.width rp.height]);
   % image = frame.cdata;

%     if phi == -0.75 || phi == 0.75 %phi ~= 0 || phi ~= -1 || phi ~= 1
%         off = 120;
%         image = image(rp.width/2-off:rp.width/2+off,rp.height/2-off:rp.height/2+off,:);
%         image = imresize(image, [rp.width, rp.height]);
%     end
    
end