package Treex::Block::W2A::RU::ParseMalt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::ParseMalt';
use Lingua::Interset qw(decode encode);

has model_name => (is=>'ro', isa=>'Str', default=> 'malt_stacklazy.mco');

has '+model' => ( lazy_build => 1 );
has '+pos_attribute' => (  default => 'conll/pos' );
has '+cpos_attribute' => ( default => 'conll/cpos' );
has '+feat_attribute' => ( default => 'iset');
has '+deprel_attribute' => ( default => 'afun' );

sub _build_model {
    my ($self) = @_;
    my ($filename) = $self->require_files_from_share('data/models/malt_parser/ru/'.$self->model_name);
    return $filename;
}

# W2A::TagTreeTagger is trained on HamleDT 2.0 version of SynTagRus,
# so it fills $anode->tag with serialized Interset features, e.g.:
# pos=adj|gender=masc|animateness=inan|number=sing|case=acc
# Let's deserialize the features into $anode->iset
# convert it to PDT-like tag and fill conll/cpos and conll/pos.
before process_atree => sub {
    my ($self, $aroot) = @_;
    foreach my $anode ($aroot->get_descendants()){
        my @features = split /\|/, $anode->tag;
        my $fs;
        foreach my $feat (@features){
            my ($name, $value) = split /=/, $feat;
            $anode->iset->set($name, $value);
            $fs->{$name} = $value;
        }
        my $pdt_tag = encode('cs::pdt', $fs, 1);
        $anode->set_conll_pos($pdt_tag);
        $anode->set_conll_cpos(substr($pdt_tag, 0, 1));
    }
    return;
};

1;

__END__

=head1 NAME

Treex::Block::W2A::RU::ParseMalt

=head1 DECRIPTION

Default setting for Russian Malt parser trained on HamleDT 2.0.

=head1 SEE ALSO

L<Treex::Block::W2A::ParseMalt> base class

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
