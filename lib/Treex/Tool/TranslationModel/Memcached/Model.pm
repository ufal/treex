package Treex::Tool::TranslationModel::Memcached::Model;
use Treex::Core::Common;
use Class::Std;
use Storable;
use IO::Zlib;
use PerlIO::gzip;
use Treex::Tool::ML::NormalizeProb;
use File::Slurp;
use Cache::Memcached;
use File::Basename;
use Treex::Tool::Memcached::Memcached;

my $minimum_usage = 3;

{
    our $VERSION = '0.01';

    our %input_label2submodel : ATTR;

    our %model : ATTR;

    our %memd : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;

        $model{ident $self} = $arg_ref->{model};
        $memd{ident $self} = Treex::Tool::Memcached::Memcached::get_connection(basename($arg_ref->{file}));

        if ( ! $memd{ident $self} ) {
            log_fatal "Memcached server is not running!.";
        }

        return;
    }

    sub get_prob {
        my ($self, $input_label, $output_label) = @_;
        $self->_load($input_label);
        
        my $prob = $model{ident $self}->get_prob($input_label, $output_label);
        $self->_clear($input_label);
        return $prob;
    }

    sub add_submodel {
        my ( $self, $input_label, $submodel ) = @_;
        $model{ident $self}->add_submodel($input_label, $submodel);
        return;
    }

    sub get_submodel {
        my ( $self, $input_label ) = @_;
        $self->_load($input_label);
        return $input_label2submodel{ident $self}{$input_label};
    }

    sub delete_submodel {
        my ( $self, $input_label ) = @_;
        $model{ident $self}->delete_submodel($input_label);
        return;
    }

    sub get_translations {
        my ($self, $input_label, $features_old_rf, $features_rf) = @_;
        $self->_load($input_label);

        my @translations = $model{ident $self}->get_translations($input_label, $features_old_rf, $features_rf);
        $self->_clear($input_label);

        return @translations;
    }

    sub _load {
        my ( $self, $input_label ) = @_;

        if ( ! defined($input_label2submodel{ident $self}{$input_label}) ||
            $input_label2submodel{ident $self}{$input_label} < $minimum_usage ) {
            # log_info "Loading label: $input_label";
            $input_label2submodel{ident $self}{$input_label}++;
            $self->add_submodel($input_label, $memd{ident $self}->get(
                Treex::Tool::Memcached::Memcached::fix_key($input_label)
            ));
        }

        return;
    }

    sub _clear {
        my ( $self, $input_label ) = @_;

        if ( $input_label2submodel{ident $self}{$input_label} < $minimum_usage ) {
            # log_info "Deleting label: $input_label";
            $self->delete_submodel($input_label);
        }

        return;
    }

    sub predict {
        my ($self, $input_label, $features_rf) = @_;
        my ($first_translation) = $self->get_translations($input_label, $features_rf);
        if (defined $first_translation) {
            return $first_translation->{label};
        }
        else {
            return;
        }
    }

    sub get_input_labels {
        my ($self) = @_;
        return $model{ident $self}->get_input_labels();
    }

    sub load {
        my ($self, $filename) = @_;
        print "NOT IMPLEMENTED!!!";

        return;
    }

    sub save {
        my ($self, $filename) = @_;
        print "NOT IMPLEMENTED!!!";

        return;
    }

    sub stringify {
        my ($self) = @_;
#        my $output;

        print "NOT IMPLEMENTED!!!";
        return;
=item
        foreach my $input_label (sort $self->get_input_labels) {
            $output .= "input_label=$input_label\n";
            my $intern = $input_label2submodel{ident $self}{$input_label};
#            ($intern->{x_list}, $intern->{y_list}, $intern->{f_map}, $intern->{lambda})
#                 = @{$input_label2submodel{ident $self}{$input_label}};

             $intern->{x_num} = scalar(@{$intern->{x_list}});
             $intern->{y_num} = scalar(@{$intern->{y_list}});
             $intern->{f_num} = scalar(@{$intern->{lambda}});

             for (0 .. $intern->{x_num} - 1) {
                $intern->{x_bucket}->{$intern->{x_list}->[$_]} = $_;
             }

             for (0 .. $intern->{y_num} - 1) {
                $intern->{y_bucket}->{$intern->{y_list}->[$_]} = $_;
             }

             my @features = @{$intern->{x_list}};
             my @classes = @{$intern->{y_list}};


             foreach my $class (@classes) {
                 my $class_number = $intern->{y_bucket}->{$class};
                 my %weight;
                 $output .= "\toutput_label=$class\n";
                 foreach my $feature (@features) {
                     my $feature_number = $intern->{x_bucket}->{$feature};
                     my $lambda_index = $intern->{f_map}->[$class_number]->[$feature_number];
                     if ( $lambda_index != -1) {
                         $weight{$feature} = $intern->{lambda}->[$lambda_index];
                     }
                 }

                 foreach my $feature (sort {$weight{$b}<=>$weight{$a}} keys %weight) {
                     $output .= "\t\t$feature\t$weight{$feature}\n";
                 }

             }
        }
        return $output;
=cut        
    }
}



1;

__END__


=head1 NAME

TranslationModel::NaiveBayes::Model



=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2012 Martin Majlis.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
