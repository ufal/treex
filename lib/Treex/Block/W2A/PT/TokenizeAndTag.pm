package Treex::Block::W2A::PT::TokenizeAndTag;
use Moose;
use Treex::Tool::LXSuite::LXTokenizerAndTagger;
extends 'Treex::Core::Block';

has lxsuite_host => ( isa => 'Str', is => 'ro', required => 1);
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 1);
has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has _tt => ( isa => 'Treex::Tool::LXSuite::LXTokenizerAndTagger',
    is => 'ro', required => 1, builder => '_build_tt', lazy => 1 );

sub BUILD {
    my $self = shift;
    $self->_tt; # this forces $self->_build_tokenizer()
}

sub _build_tt {
    my $self = shift;
    return Treex::Tool::LXSuite::LXTokenizerAndTagger->new({
        lxsuite_key => $self->lxsuite_key,
        lxsuite_host => $self->lxsuite_host,
        lxsuite_port => $self->lxsuite_port,
    });
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my ($forms, $lemmas, $postags, $cpostags, $feats) = $self->_tt->tokenize_and_tag($zone->sentence);

    my $a_root = $zone->create_atree();
    my $prev_node = undef;
    foreach my $i ( ( 0 .. $#$forms ) ) {
        my $no_space_after = 0;
        my ($left, $form, $right) = $forms->[$i] =~ /^(\\\*)?(.+?)(\*\/)?$/;
        if ($form =~ /^\pP$/) {
            $prev_node->set_no_space_after(1) if defined $prev_node and !defined $left;
            $no_space_after = 1 if !defined $right;
        } elsif ($form =~ /_$/) {
            $no_space_after = 1;
        }
        $prev_node = $a_root->create_child({
            form           => $form,
            no_space_after => $no_space_after,
            ord            => $i + 1,
            lemma          => $lemmas->[$i],
            'conll/pos'    => $postags->[$i],
            'conll/cpos'   => $cpostags->[$i],
            'conll/feat'   => $feats->[$i]
        });
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
