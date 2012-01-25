package Treex::Block::Align::A::MonolingualGreedy;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::MonolingualGreedy;
extends 'Treex::Core::Block';

has to_language => (
    is         => 'ro',
    isa        => 'Treex::Type::LangCode',
    lazy_build => 1,
);

has to_selector => (
    is      => 'ro',
    isa     => 'Treex::Type::Selector',
    default => 'ref',
);

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

has '+language' => ( required => 1 );

has _tool => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't align a zone to itself.");
    }
    my $tool = Treex::Tool::Align::MonolingualGreedy->new(@_);
    $self->_set_tool($tool);
    return;
}

# h = hypothesis (i.e. MT output)
# r = reference
# alignment is from h to r
sub process_zone {
    my ( $self, $h_zone ) = @_;
    my $r_zone = $h_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @h_nodes = $h_zone->get_atree->get_descendants( { ordered => 1 } );
    my @r_nodes = $r_zone->get_atree->get_descendants( { ordered => 1 } );
    return if @r_nodes == 0;    # because of re-segmentation

    my $args = {
        hforms  => [ map { $_->form } @h_nodes ],
        rforms  => [ map { $_->form } @r_nodes ],
        hlemmas => [ map { $_->lemma } @h_nodes ],
        rlemmas => [ map { $_->lemma } @r_nodes ],
        htags   => [ map { $_->tag } @h_nodes ],
        rtags   => [ map { $_->tag } @r_nodes ],
    };
    my $alignment = $self->_tool->align_sentence($args);

    for my $h ( 0 .. $#h_nodes ) {
        my $r = $alignment->[$h];
        if ( $r != -1 ) {
            $h_nodes[$h]->add_aligned_node( $r_nodes[$r], 'monolingual' );
        }
    }

    return;
}

1;

__END__
 
=head1 NAME

Treex::Block::Align::A::MonolingualGreedy - align paraphrases, e.g. MT-output and reference

=head1 DESCRIPTION

Aligns two zones (a-trees in those zones) which are suposed to be in a same or similar language.
Only one-to-one alignments are created, but some words may remain unaligned.
If there were some alignment links before applying this block, they will be preserved.
Forms, lemmas and tags are exploited.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Tool::Align::MonolingualGreedy>

=head1 COPYRIGHT

Copyright 2012 Martin Popel
This file is distributed under the GNU General Public License v2 or later.
