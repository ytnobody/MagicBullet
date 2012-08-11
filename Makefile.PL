use inc::Module::Install;
name 'MagicBullet';
all_from 'lib/MagicBullet.pm';

requires 'Path::Class';
requires 'Git::Class';
requires 'Getopt::Long';
requires 'Digest::MD5';
requires 'Net::SSH::Perl';
requires 'Data::Dumper::Concise';
requires 'Guard';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
