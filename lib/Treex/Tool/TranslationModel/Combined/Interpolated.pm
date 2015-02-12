package Treex::Tool::TranslationModel::Combined::Interpolated;
use Treex::Core::Common;
use Class::Std;
use Storable;

use base qw(Treex::Tool::TranslationModel::Common);

{
    our $VERSION = '0.01';

    our %sequence_of_models : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;

        if ($arg_ref->{models}) {
            $sequence_of_models{ident $self} = $arg_ref->{models};
            log_info "Interpolated translation model with ".
                  scalar(@{$arg_ref->{models}})." models initialized.";
        }
        else {
            log_fatal "A sequence of models must be specified!";
        }

        my $weight_sum;
        foreach my $weight (map {$_->{weight}} @{$arg_ref->{models}}) {
            $weight_sum += $weight;
        }

        foreach my $weighted_model (@{$arg_ref->{models}}) {
            $weighted_model->{weight} = $weighted_model->{weight}/$weight_sum;
        }

        return $self;
    }

    # TODO: change to sub get_unnormalized_translations {
    sub get_translations {
        my ($self, $input_label, $features_rf) = @_;

        my %weighted_sum;
        my %source;
        my %feat_weights;

        foreach my $weighted_model (@{$sequence_of_models{ident $self}}) {
            my $model = $weighted_model->{model};
            my $weight = $weighted_model->{weight};

            my @transls = $model->get_translations($input_label, $features_rf);

            #my $max = scalar @transls > 3 ? 2 : (scalar @transls - 1);
            #foreach my $transl (@transls[0 .. $max]) {
                #log_info "PROB: " . $transl->{prob};
                #log_info "OUTPUT: " . $transl->{label};
            #}

            foreach my $translation (@transls) {
                $weighted_sum{$translation->{label}} += $weight * $translation->{prob};
                if ($source{$translation->{label}}) {
                    push @{$source{$translation->{label}}}, $translation->{source};
                }
                else {
                    $source{$translation->{label}} = [ $translation->{source} ];
                }
                if (!defined $feat_weights{$translation->{label}} && defined $translation->{feat_weights}) {
                    $feat_weights{$translation->{label}} = $translation->{feat_weights};
                }
            }
        }

        return map {{ label => $_,
                          prob => $weighted_sum{$_},
                              source => "interpolated:".join(" ",@{$source{$_}}),
                              feat_weights => $feat_weights{$_},
                      }}
            sort {($weighted_sum{$b} <=> $weighted_sum{$a}) || ($a cmp $b)}
                keys %weighted_sum;
    }

}


1;

__END__


=head1 NAME

TranslationModel::Combined::Interpolated


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
