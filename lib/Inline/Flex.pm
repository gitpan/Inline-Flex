
package Inline::Flex ;

use base 'Inline::C' ;
use Config ;

use strict;
use warnings ;
use Carp qw(carp croak confess) ;

BEGIN 
{
use Sub::Exporter -setup => 
	{
	exports => [ qw() ],
	groups  => 
		{
		all  => [ qw() ],
		}
	};
	
use vars qw ($VERSION);
$VERSION     = '0.01_01';
}

#-------------------------------------------------------------------------------

use English qw( -no_match_vars ) ;

use Readonly ;
Readonly my $EMPTY_STRING => q{} ;

use File::Slurp ;

#-------------------------------------------------------------------------------

=head1 NAME

Inline::Flex - Inline module to use flex generated lexers

=head1 SYNOPSIS

  use Inline Flex =><<'END_FLEX' ;
  %option noyywrap
  %option prefix="Default"
  
  %{
  #undef YY_MAIN
  #define INTEGER 1
  #define IDENTIFIER 2
  #define UNEXPECTED 3
  %}
  
  %{
  // replacement macros
  %}
  exp		(([eE][0-9]+)?)
  fltsuf   (([lL]|[fF])?)
  intsuf   (([lL]?[uU]?)|([uU]?[lL]?))
  
  %%
  
  %{
  // regexes and action code
  %}
  [1-9][0-9]*{intsuf} { return(INTEGER) ; }
  
  [a-z_A-Z][a-z_A-Z0-9]+ { return(IDENTIFIER) ; } 
  
  \ + // ignore
  [\n\t ]+ ; // ignore
  
  [^a-z_A-Z0-9 ]+ { return(UNEXPECTED) ; } 
  
  %{
  // comment section
  %}
  
  %%
  END_FLEX
  
  print <<'EOT' ;
  Type an integer or an identfier and end your input with a '\n'.
  End the program with ctl+c
  
  EOT
  
  my %type = ( 1 => 'INTEGER',  2 => 'IDENTIFIER', 3 => 'UNEXPECTED') ;
  
  while(0 != (my $lexem = yylex()))
	{
	if(exists $type{$lexem})
		{
		print  "$type{$lexem} [$lexem] .\n" ;
		}
	else
		{
		print "Can't find type [$lexem] !\n" ;
		}
	}

=head1 DESCRIPTION

Inline::Flex Allows you to define a lexer with the help of B<flex> and to use it in perl.
Inline::Flex inherits B<from Inline::C>. All the option available in B<Inline::C> are
also available in Inline::Flex.

As of version 0.02 all C functions declared in the lexer are made available to perl. 

A B<'yylex'> sub is exported to perl space by this module.

=item Limitation

You can't write your lexer after the __END__ tag. You must write it inline where you declare your Inline::Flex section.
If your lexer is so big that you need to separate it from the rest of your code, considermoving it to another package.

=item Inline::Flex aliases:

Inline::FLEX

Inline::flex

=item Options

Inline::Flex supports the following options:

FLEX_COMMAND_LINE:

This is the command line used to generate the lexer.  It defaults to 'flex -f -8 -oOUTPUT_FILE INPUT_FILE' 
where OUTPUT_FILE and INPUT_FILE are automatically replaced by Inline::Flex. This option allows to tweak 
the generated lexers. Look at the flex man page for more information.

=head1 SUBROUTINES/METHODS

=cut


#-------------------------------------------------------------------------------

sub register
{

=head2 register()

Register this module as an Inline language support module . This is called by Inline.

I<Arguments> - None

I<Returns> - See L<Inline::C>

I<Exceptions> - None

=cut

return 
	{
	language => 'Flex',
	aliases => ['FLEX', 'flex'],
	type => 'compiled',
	suffix => $Config{dlext},
	} ;
}

#-------------------------------------------------------------------------------

sub validate 
{

=head2 validate($self, %configuration)

Sets default command line or uses user defined command line.

I<Arguments>

=over 2 

=item $self - inline object.

=item %configuration - options

=back

I<Returns> - Inline::C configuration validation code

See L<Inline>

=cut

my ($self, %configuration) = @_ ;

# set default command line
$self->{ILSM}{FLEX_COMMAND_LINE} = 'flex -f -8 -oOUTPUT_FILE INPUT_FILE' ;
		
while (my ($key, $value) = each %configuration) 
	{
	if ($key eq 'FLEX_COMMAND_LINE')
		{
		$self->{ILSM}{$key} = $value  ;
		delete $configuration{$key} ;
		}
	}
	
$self->SUPER::validate(%configuration) ;
}

#-------------------------------------------------------------------------------

sub build 
{

=head2 build($self)

Generate the lexer and calls Inline::C to compile it.

I<Arguments>

=over 2 

=item $self - Inline object

=back

I<Returns> - Inline::C build result

I<Exceptions> - None

=cut

my ($self) = @_ ;
   
$self->GenerateLexer() ;
$self->SUPER::build() ;
}

#-------------------------------------------------------------------------------

sub GenerateLexer
{

=head2 GenerateLexer($self)

Creates the C code Inline::C will compile by preprocessing the Inline::Flex input code with B<flex>.

I<Arguments>

=over 2 

=item * $self - the Inline object

=back

I<Returns> - Nothing

I<Exceptions> - B<flex> command failures

=cut

my ($self) = @_ ;

$self->mkpath($self->{API}{build_dir}) ;

my $flex_file_base       = "$self->{API}{build_dir}/$self->{API}{module}" ;
my $flex_file            = "$flex_file_base.flex" ;
my $flex_generated_lexer = "$flex_file_base.flex.c" ;

write_file $flex_file, $self->{API}{code} ;

$self->{ILSM}{FLEX_COMMAND_LINE} =~ s/OUTPUT_FILE/$flex_generated_lexer/smxg ;
$self->{ILSM}{FLEX_COMMAND_LINE} =~ s/INPUT_FILE/$flex_file/smxg ;

system($self->{ILSM}{FLEX_COMMAND_LINE}) == 0
	 or croak "Error: '$self->{ILSM}{FLEX_COMMAND_LINE}' failed: $? $! $@" ;

$self->{API}{code} = read_file $flex_generated_lexer ;

# name yylex so Inline::C can find it
$self->{API}{code} =~ s/YY_DECL\s+{/int yylex()\n{/smx ; 

# delete main so Inline::C does NOT find it
$self->{API}{code} =~ s/#if YY_MAIN.+?#endif//smx ;

write_file $flex_generated_lexer, $self->{API}{code} ;

return ;
}

#-------------------------------------------------------------------------------

1 ;

=head1 BUGS AND LIMITATIONS

None so far.

=head1 AUTHOR

	Nadim ibn hamouda el Khemir
	CPAN ID: NH
	mailto: nadim@cpan.org

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Inline::Flex

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Inline-Flex>

=item * RT: CPAN's request tracker

Please report any bugs or feature requests to  L <bug-inline-flex@rt.cpan.org>.

We will be notified, and then you'll automatically be notified of progress on
your bug as we make changes.

=item * Search CPAN

L<http://search.cpan.org/dist/Inline-Flex>

=back

=head1 SEE ALSO

flex (1).

=cut

