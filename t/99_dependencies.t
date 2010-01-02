use ExtUtils::MakeMaker;
use Test::Dependencies
exclude => [qw(
	Test::Dependencies Test::Perl::Critic
	Net::FTP::Find
)], style   => 'light';
ok_dependencies();
