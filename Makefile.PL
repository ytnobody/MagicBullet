use inc::Module::Install;
name 'MagicBullet';
all_from 'lib/MagicBullet.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
