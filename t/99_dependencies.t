use ExtUtils::MakeMaker;
use Test::Dependencies
exclude => [qw(
	Test::Dependencies Test::Perl::Critic
	Test::TCP Test::FTP::Server
	Net::FTP::Find
)], style   => 'light';
ok_dependencies();
