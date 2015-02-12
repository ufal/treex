package Treex::Tool::TranslationModel::Static::Model;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::TranslationModel::Model';

# both old and new types of submodels supported
has '+_submodels' => (
    isa => 'HashRef[HashRef[Num]]',
);

sub source {
    return "static";
}

sub set_prob {
    my ($self, $input_label, $output_label, $prob) = @_;
    $self->_submodels->{$input_label}{$output_label} = $prob;
    return;
}

sub get_prob {
    my ($self, $input_label, $output_label) = @_;
    return $self->_submodels->{$input_label}{$output_label} || 0;
}

sub accepts {
    my ($self, $input_label, $output_label) = @_;
    return $self->_submodels->{$input_label}{$output_label} ? 1 : 0;
}

sub _get_transl_variants {
    my ($self, $submodel) = @_;
    my @variants = map {{ 
            label => $_,
            prob => $submodel->{$_},
            source => $self->source,
        }} keys %{$submodel};
    #log_info "CLASSES: " . scalar(keys %{$submodel});
    return @variants;
}

############# implementing Treex::Tool::Storage::Storable role #################
############# overriding the implementation in Treex::Tool::TranslationModel::Model #########

around 'thaw' => sub {
    my ($orig, $self, $model) = @_;
    $self->_submodels($model);
};

around 'freeze' => sub {
    my ($orig, $self) = @_;
    return $self->_submodels;
};

# TODO: this is not an ellegant solution
# it should be solved rather by composition, not inheritance
sub _create_submodel {
}

#######################################################################

sub stringify_as_tsv {
    my ($self) = @_;
    my $output;
    foreach my $input_label (sort $self->get_input_labels) {
        if ($output) {
            $output .= "\n";
        }
        foreach my $translation ($self->get_translations($input_label)) {
            $output .= "$input_label\t$translation->{label}\t$translation->{prob}\n";
        }
    }
    return $output;
}


1;

__END__


=head1 NAME

TranslationModel::Static::Model


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
