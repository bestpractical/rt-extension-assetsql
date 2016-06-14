use inc::Module::Install;

RTx 'RT-Extension-AssetSQL';

requires_rt '4.4';
rt_too_new '4.6';

perl_version '5.010001';

WriteAll;
