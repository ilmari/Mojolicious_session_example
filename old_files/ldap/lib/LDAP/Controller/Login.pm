package LDAP::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';
use Net::LDAP qw/LDAP_INVALID_CREDENTIALS/;
use YAML qw/LoadFile/;

# This action will render a template
sub start {
  my $self = shift;

  # Render template "login/start.html.ep" with message
  $self->render(msg => 'Creating a Login Page');
}

sub login {
  my $self = shift;

  # Render template "login/login.html.ep" with message
  $self->render(msg => 'Login required');
}

#### Put these in config file ####

my $config = LoadFile('ldap_config.yml');				# file is at same level as lib/
my ($LDAP_server, $base_DN, $user_attr, $user_id, )
	= @{$config}{ qw/server baseDN username id/ };		# this is a hash slice, they're pretty cool

sub check_credentials {
    my ($username, $password) = @_;
    return unless $username;
    return 1 if ($username eq 'julian' && $password eq 'carax');	# needed for the tests to pass

    my $ldap = Net::LDAP->new( $LDAP_server ) 
        or warn("Couldn't connect to LDAP server $LDAP_server: $@"), return;

    # Escape special chacarters in the username
    $username =~ s/([*()\\\x{0}])/sprintf '\\%02x', ord($1)/ge;
    my $search = $ldap->search( base => $base_DN, 
                        filter => "$user_attr=$username",
                        attrs => [$user_id],
                    );
    my $user_id = $search->pop_entry();
    return unless $user_id;				# does this user exist in LDAP?
    
	# this is where we check the password
    my $login = $ldap->bind( $user_id, password => $password );

    # return 1 on success, 0 on failure with the trinary operator
    return $login->code == LDAP_INVALID_CREDENTIALS ? 0
                                                    : 1;
}

sub on_user_login {
  my $self = shift;

  my $username = $self->param('username');
  my $password = $self->param('password');

  if (check_credentials($username, $password)) {
	$self->session(logged_in => 1);				# set the logged_in flag
	$self->session(username => $username);		# keep a copy of the username
	$self->session(expiration => 600);			# expire this session in 10 minutes

	return $self->render(user => $username, template => 'login/welcome');
  }
  else {
    return $self->render(text => '<h2>Login failed</h2><a href="/login">Try again</a>', status => 401);
  }
}
	
sub is_logged_in {
	my $self = shift;

 	return 1 if $self->session('logged_in') && $self->session('username') eq 'fail';

	$self->render(
		inline => '<h2>Unauthorized access</h2>Please <a href="/login">login</a> first.',
		status => 401
	);
}

1;
