use inc::Module::Install;
name 'MagicBullet';
all_from 'lib/MagicBullet.pm';

requires 'Path::Class';
requires 'Git::Class';
requires 'Getopt::Casual';
requires 'Digest::MD5';
requires 'Net::SSH::Perl';
requires 'Data::Dumper::Concise';
requires 'Guard';
requires 'YAML';
requires 'JSON';
requires 'Pod::Help';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';

install_script 'bin/magic-bullet';

auto_set_repository;
auto_include;
WriteAll;
