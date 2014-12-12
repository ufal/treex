package Treex::Block::W2A::PT::Tokenize;

use File::Basename;
use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;
use Treex::Tool::LXSuite::LXTokenizer;

extends 'Treex::Core::Block';
# I didn't extend Treex::Block::W2A::TokenizeOnWhitespace and instead
#  adapted sub process_zone because LX-Tokenizer modifies punct tokens
#  in a way that TokenizeOnWhitespace would fail when trying to determine
#  the no_space_after attribute of a-tree nodes.

has lxsuite_host => ( isa => 'Str', is => 'ro', required => 1);
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 1);
has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has _tokenizer => ( isa => 'Treex::Tool::LXSuite::LXTokenizer', is => 'ro',
    required => 1, builder => '_build_tokenizer', lazy=>1 );

sub BUILD {
    my ($self, $arg_ref) = @_;
    $self->_tokenizer; # this forces $self->_build_tokenizer()
}

sub _build_tokenizer {
    my $self = shift;
    return Treex::Tool::LXSuite::LXTokenizer->new({
        lxsuite_key => $self->lxsuite_key,
        lxsuite_host => $self->lxsuite_host,
        lxsuite_port => $self->lxsuite_port,
    });
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;
    my @tokens = split( /\s+/, $self->_tokenizer->tokenize($sentence));

    # create a-tree
    my $a_root = $zone->create_atree();
    my $prev_node = undef;
    # Create a-nodes and detect the no_space_after attribute.
    foreach my $i ( ( 0 .. $#tokens ) ) {
        my $token = $tokens[$i];
        my $no_space_after = 0;
        my ($left, $form, $right) = $token =~ /^(\\\*)?(.+?)(\*\/)?$/;
        if ($form =~ /^\pP$/) {
            $prev_node->set_no_space_after(1) if defined $prev_node and !defined $left;
            $no_space_after = 1 if !defined $right;
        } elsif ($form =~ /_$/) {
            $no_space_after = 1;
        }
        $prev_node = $a_root->create_child(
            form           => $token,
            no_space_after => $no_space_after,
            ord            => $i + 1,
        );
    }
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::PT::Tokenize

=head1 DESCRIPTION

Uses LX-Suite tokenizer to split a sentence into a sequence of tokens.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
