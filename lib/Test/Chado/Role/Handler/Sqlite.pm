package Test::Chado::Role::Handler::Sqlite;

use version; our $VERSION = qv('0.1');

# Other modules:
use Moose::Role;
use Carp;
use File::Basename;
use File::Path;
use Try::Tiny;
use IPC::Cmd qw/can_run run/;
use Path::Class;
use namespace::autoclean;

# Module implementation
#
requires 'driver';
requires 'dsn';
requires 'database';

has 'client' => (
    is        => 'rw',
    isa       => 'Maybe[Str]',
    predicate => 'has_client',
    default   => sub {
        can_run 'sqlite3';
    }
);

has 'attr_hash' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { { AutoCommit => 1 } },
    handles => { add_dbh_attribute => 'set' }
);

after 'driver_dsn' => sub {
    my ( $self, $value ) = @_;
    if ( $value =~ /(dbname|(.+)?)=(\S+)/ ) {
        $self->database( Path::Class::File->new($3)->absolute->stringify );
    }
};

sub create_db {
    my ($self) = @_;

    #create the parent folder if it does not exist
    my $folder = dirname $self->database;
    if ( !-e $folder ) {
        try {
            mkpath $folder;
        }
        catch {
            confess $_;
        };
    }

	#nothing to do if the client exist
	#the database will be created in the deployment call
    return if $self->has_client ;
    $self->dbh;
}

sub drop_db {
    my ($self) = @_;
    $self->dbh->disconnect if $self->has_db;
    unlink $self->database if -e $self->database;
}

has 'dbh' => (
    is        => 'ro',
    isa       => 'DBI::db',
    predicate => 'has_db',
    lazy      => 1,
    default   => sub {
        my ($self) = @_;
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        $dbh->do("PRAGMA foreign_keys = ON");
        $dbh;
    }
);

has 'connection_info' => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy       => 1,
    auto_deref => 1,
    default    => sub {
        my ($self) = @_;
        [ $self->dsn, '', '', $self->attr_hash ];
    }
);

sub deploy_schema {
    my $self = shift;
    $self->deploy_by_dbi if !$self->deploy_by_client;
    $self->dbh; #making sure the pragma is run
}

sub deploy_post_schema {
	return;
}

sub deploy_by_client {
    my $self = shift;
    return if !$self->has_client;
    my $cmd = [
        $self->client,   '-noheader',
        $self->database, '<',
        $self->ddl
    ];
    my ( $success, $error_code, $full_buf,, $stdout_buf, $stderr_buf )
        = run( command => $cmd, verbose => 1 );
    return $success if $success;
    carp "unable to run command : ", $error_code, " ", $stderr_buf;
}

sub deploy_by_dbi {
    my ($self) = @_;
    my $dbh    = $self->dbh;
    my $fh     = Path::Class::File->new($self->ddl)->openr;
    my $data = do { local ($/); <$fh> };
    $fh->close();
LINE:
    foreach my $line ( split( /\n{2,}/, $data ) ) {

        #next LINE if $line =~ /^\-\-/;
        if ( $line =~ /^\-\-/ ) {
            my @separated = grep { !/^\-\-/ } split( /\n/, $line );
            $line = join( "\n", @separated );
        }
        next LINE if $line !~ /\S+/;
        $line =~ s{;$}{};
        $line =~ s{/}{};
        try {
            $dbh->do($line);
            $dbh->commit;
        }
        catch {
            $dbh->rollback;
            confess $_, "\n";
        };
    }
}

sub run_fixture_hooks {
    my ($self) = @_;
    $self->dbh->do("PRAGMA foreign_keys = ON");
}

sub prune_fixture {
    my ($self) = @_;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare(
        qq{SELECT name FROM sqlite_master where type = 'table' });
    $sth->execute() or croak $sth->errstr;
    while ( my ($table) = $sth->fetchrow_array() ) {
        try {
            $dbh->do(qq{ DELETE FROM $table });
        }
        catch {
            $dbh->rollback;
            croak "Unable to clean table $table: $_\n";
        };
    }
    $dbh->commit;
}

sub drop_schema {
	my ($self) = @_;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare(
        qq{SELECT name FROM sqlite_master where type = 'table' });
    $sth->execute() or croak $sth->errstr;
    while ( my ($table) = $sth->fetchrow_array() ) {
        try {
            $dbh->do(qq{ DROP TABLE $table });
        }
        catch {
            $dbh->rollback;
            croak "Unable to clean table $table: $_\n";
        };
    }
    $dbh->commit;

}


1;    # Magic true value required at end of module

__END__

=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


=head1 SYNOPSIS

use <MODULE NAME>;

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back


=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.

<MODULE NAME> requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
A list of all the other modules that this module relies upon,
  including any restrictions on versions, and an indication whether
  the module is part of the standard Perl distribution, part of the
  module's distribution, or must be installed separately. ]

  None.


  =head1 INCOMPATIBILITIES

  =for author to fill in:
  A list of any modules that this module cannot be used in conjunction
  with. This may be due to name conflicts in the interface, or
  competition for system or program resources, or due to internal
  limitations of Perl (for example, many modules that use source code
		  filters are mutually incompatible).

  None reported.


  =head1 BUGS AND LIMITATIONS

  =for author to fill in:
  A list of known problems with the module, together with some
  indication Whether they are likely to be fixed in an upcoming
  release. Also a list of restrictions on the features the module
  does provide: data types that cannot be handled, performance issues
  and the circumstances in which they may arise, practical
  limitations on the size of data sets, special cases that are not
  (yet) handled, etc.

  No bugs have been reported.Please report any bugs or feature requests to
  dictybase@northwestern.edu



  =head1 TODO

  =over

  =item *

  [Write stuff here]

  =item *

  [Write stuff here]

  =back


  =head1 AUTHOR

  I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>


  =head1 LICENCE AND COPYRIGHT

  Copyright (c) B<2003>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself. See L<perlartistic>.


  =head1 DISCLAIMER OF WARRANTY

  BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
  FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
  OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
  PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
  ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
  YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
  NECESSARY SERVICING, REPAIR, OR CORRECTION.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
  REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
  LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
  THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
		  RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
		  FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
  SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGES.



