package Params::Validate::Dependencies;

use strict;
use warnings;

use Params::Validate (); # don't import yet

use base qw(Exporter);

use Data::Dumper;
local $Data::Dumper::Indent=1;

use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = '1.00';
my @_of = qw(any_of all_of none_of one_of);
@EXPORT = (@Params::Validate::EXPORT, @_of);
@EXPORT_OK = (@Params::Validate::EXPORT_OK, @_of);
%EXPORT_TAGS = (%Params::Validate::EXPORT_TAGS, _of => \@_of);
push @{$EXPORT_TAGS{all}}, @_of;

# because repeating the call to _validate_factory_args everywhere is BAD
foreach my $sub (@_of) {
  no strict 'refs';
  no warnings 'redefine';
  my $orig = \&{$sub};
  *{$sub} = sub {
    _validate_factory_args(@_);
    $orig->(@_);
  };
}

sub import {
  Params::Validate->import(grep { $_ ne 'validate' } @Params::Validate::EXPORT_OK);
  __PACKAGE__->export_to_level(1, @_);
}

=head1 NAME

Params::Validate::Dependencies

=head1 DESCRIPTION

Extends Params::Validate to make it easy to validate
that you have been passed the correct combinations of parameters.

=head1 SYNOPSIS

This example validates that sub 'foo's arguments are of the right types,
and that either we have at least one of alpha, beta and gamma, or
we have both of bar amd baz:

  use Params::Validate::Dependencies qw(:all);

  sub foo {
    validate(@_,
      {
        alpha => { type => ARRAYREF, optional => 1 },
        beta  => { type => ARRAYREF, optional => 1 },
        gamma => { type => ARRAYREF, optional => 1 },
        bar   => { type => SCALAR, optional => 1 },
        baz   => { type => SCALAR, optional => 1 },
      },
      any_of(
        qw(alpha beta gamma),
        all_of(qw(bar baz)),
      )
    );
  }

=head1 HOW IT WORKS

Params::Validate::Dependencies extends Params::Validate's
validate() function to
support an arbitrary number of callbacks which are not associated
with any one parameter.  All of those callbacks are run after
Params::Validate's normal validate() function.  They take as their
only argument a hashref of the parameters to check.  They should
return true if the params are good, false otherwise.  If any of
them return false, then validate() will die as normal.

=head1 SUBROUTINES and EXPORTS

All of the *_of functions are exported by default in addition to those
exported by default by Params::Validate.  They are also available with the
tag ':_of' in case you want to use them without Params::Validate.
In that case you would load the module thus:

  use Params::Validate::Dependencies qw(:_of);

=head2 validate

Overrides and extends Params::Validate's function of the same name.

=cut

sub validate {
  my @args = @_;
  my @coderefs = ();
  while(ref($args[-1]) && ref($args[-1]) =~ /CODE/) {
    unshift(@coderefs, pop(@args));
  }
  my $spec = pop(@args);
  
  Params::Validate::validate(@args, $spec);
  foreach (@coderefs) {
    die("code-ref checking failed\n") unless($_->({@args}));
  }
}

=head2 none_of

Returns a code-ref which checks that the hashref it receives matches
none of the options given.

You might want to use it thus:

  all_of(
    'alpha',
    none_of(qw(bar baz))
  )

to validate that 'alpha' must *not* be accompanied by 'bar' or 'baz'.

=cut

sub none_of {
  my @options = @_;
  return _count_of(\@options, 0);
}

=head2 one_of

Returns a code-refs which checks that the hashref it receives matches
only one of the options given.

=cut

sub one_of {
  my @options = @_;
  return _count_of(\@options, 1);
}

=head2 any_of

This returns a code-ref which
checks that the hashref it receives as its only argument contains
at least one of the specified scalar keys or which, when passed in the same
style to a code-ref, returns true.

=cut

sub any_of {
  my @options = @_;
  return sub {
    my %params = %{shift()};
    foreach my $option (@options) {
      return 1 if(!ref($option) && exists($params{$option}));
      return 1 if(ref($option) && $option->(\%params));
    }
    return 0;
  }
}

=head2 all_of

This returns a code-ref which
checks that the hashref it receives as its second argument contains
all of the specified scalar keys and which, when passed in the same
style to a code-ref, returns true.

=cut

sub all_of {
  my @options = @_;
  return _count_of(\@options, $#options + 1);
}

sub _count_of {
  my @options = @{shift()};
  my $desired_count = shift;
  sub {
    my %params = %{shift()};
    my $matches = 0;
    foreach my $option (@options) {
      $matches++ if(
        (!ref($option) && exists($params{$option})) ||
        (ref($option) && $option->(\%params))
      );
    }
    return ($matches == $desired_count);
  }
}

sub _validate_factory_args {
  my @options = @_;
  my $sub = (caller(1))[3];
  die("$sub takes only SCALARs and CODEREFs\n")
    if(grep { ref($_) && ref($_) !~ /CODE/ } @options);
}

=head1 BUGS

Please report any bugs either by email or using L<http://rt.cpan.org/>
or at L<https://github.com/DrHyde/perl-modules-Params-Validate-Dependencies/issues>.

Any incompatibility with Params::Validate will be considered to be a bug,
with the exception of minor differences in error messages.

=head1 SEE ALSO

L<Params::Validate>
L<Data::Domain>

=head1 FEEDBACK

I like to know who's using my code.  All comments, including constructive
criticism, are welcome.  Please email me.

=head1 SOURCE CODE REPOSITORY

L<git://github.com/DrHyde/perl-modules-Params-Validate-Dependencies.git>

=head1 COPYRIGHT and LICENCE

Copyright 2011 David Cantrell E<lt>F<david@cantrell.org.uk>E<gt>

This software is free-as-in-speech software, and may be used, distributed, and modified under the terms of either the GNU General Public Licence version 2 or the Artistic Licence. It's up to you which one you use. The full text of the licences can be found in the files GPL2.txt and ARTISTIC.txt, respectively.

=cut

1;
