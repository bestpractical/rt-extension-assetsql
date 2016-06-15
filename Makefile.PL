use inc::Module::Install;

RTx 'RT-Extension-AssetSQL';

no_index package => "RT::Assets";

requires_rt '4.4';
rt_too_new '4.6';

perl_version '5.010001';

WriteAll;
