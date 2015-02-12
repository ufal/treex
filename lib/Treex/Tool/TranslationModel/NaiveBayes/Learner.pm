package Treex::Tool::TranslationModel::NaiveBayes::Learner;
use Treex::Core::Common;
use Class::Std;
use Algorithm::NaiveBayes;
binmode(STDERR, ":encoding(UTF8)");

{
    our $VERSION = '0.01';

    our %model : ATTR;
    our %unprocessed_instances : ATTR;
    our %current_input_label : ATTR;
    our %current_output_label_counts : ATTR;
    our %arg_ref;
    our %submodel_learner;
    our %pair_count;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;
        $current_input_label{ident $self} = "";
        $unprocessed_instances{ident $self} = [];
        $model{ident $self} = Treex::Tool::TranslationModel::NaiveBayes::Model->new;
        $arg_ref{ident $self} = $arg_ref || {};

        return;
    }


    sub see {
        my ( $self, $input_label, $output_label, $features_rf ) = @_;
        if ($input_label ne $current_input_label{ident $self}) {
            $self->_finish;
            $current_input_label{ident $self} = $input_label;
        }

        $pair_count{ident $self}{$input_label}{$output_label} += 1;

        push @{$unprocessed_instances{ident $self}}, { label=>$output_label,
                                                       features=>$features_rf,
                                                   };
        return;
    }

#    sub reset {
#        my ($self) = @_;
#        delete $counts{ident $self};
#    }

    sub _finish {
        my ( $self ) = @_;

        my $ident = ident $self;

        my $input_label = $current_input_label{$ident};

        if ($unprocessed_instances{$ident}
                and (($arg_ref{$ident}->{min_instances}||0) <=
                    scalar @{$unprocessed_instances{$ident}})
                    and (keys %{$pair_count{$ident}{$input_label}}) > 1
            ) {

#            print STDERR "$input_label\tTRAINING from ".scalar( @{$unprocessed_instances{$ident}})."\n";

            my $max_instances = $arg_ref{ident $self}->{max_instances};

#            my $accepting_prob = 1;
#
#            if (defined $max_instances
#                    and $max_instances < scalar (@{$unprocessed_instances{$ident}})) {
#                $accepting_prob = $max_instances / scalar (@{$unprocessed_instances{$ident}});
#
#            }
            srand(1); # filtering is randomized, but reproducable

            $submodel_learner{$ident} = Algorithm::NaiveBayes->new();
            my $used_instances;
#            foreach my $instance (grep {$accepting_prob == 1 || rand() < $accepting_prob}
#                                      @{$unprocessed_instances{$ident}}) {
            foreach my $instance (@{$unprocessed_instances{$ident}}) {

                $submodel_learner{$ident}->add_instance(
                    attributes => $instance->{features},
                    label => $instance->{label} );
                #$instance->features instead of [split /\s/,$instance->{features}]
                $used_instances++;
            }

#            print STDERR "$input_label\taccepting prob:$accepting_prob\tused instances: $used_instances\n";
            print STDERR "$input_label\tused instances: $used_instances\n";

            # pruning features

            # !!! copy of code from train_nb.pl
            my $threshold_count = $submodel_learner{$ident}->instances() * $arg_ref{ident $self}->{threshold};
            for my $label (grep { $pair_count{ident $self}{$input_label}{$_} < $threshold_count} keys %{$pair_count{ident $self}{$input_label}}) {
                print STDERR "Removing: " . $label . ' - ' . $pair_count{ident $self}{$input_label}{$label} . "\n";
                delete $submodel_learner{$ident}->{labels}{$label};
                delete $submodel_learner{$ident}->{training_data}{labels}{$label};
            }

            $submodel_learner{$ident}->train;
            # $submodel_learner{$ident}->do_purge();
            $self->add_submodel($input_label,$submodel_learner{$ident});


        } else {
            print STDERR "$input_label\tREJECT\n";
        }

        $unprocessed_instances{$ident} = [];
        $pair_count{$ident} = {};

        return;
    }

    sub add_submodel {
        my ( $self, $input_label, $submodel ) = @_;
        my $ident = ident $self;
#        print STDERR "Add submodel for $input_label\n";
#        print STDERR Data::Dumper->Dump([$submodel]) . "\n";
        $model{$ident}->add_submodel($input_label, $submodel);

        return;
    }


    sub get_model {
        my ( $self ) = @_;
        $self->_finish;
        return $model{ident $self};
    }
}



1;

__END__


=head1 NAME

TranslationModel::NaiveBayes::Learner



=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2012 Martin Majlis.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
