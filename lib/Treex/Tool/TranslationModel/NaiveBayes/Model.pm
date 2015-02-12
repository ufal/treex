package Treex::Tool::TranslationModel::NaiveBayes::Model;
use Treex::Core::Common;
use Class::Std;
use Storable;
use IO::Zlib;
use PerlIO::gzip;
use Algorithm::NaiveBayes;
use Treex::Tool::ML::NormalizeProb;
use File::Slurp;

{
    our $VERSION = '0.01';

    our %input_label2submodel : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;

        # it is important to create this model
        # otherwise it crashes during loading models
        my $xyz = Algorithm::NaiveBayes->new;

        return;
    }


    sub add_submodel {
        my ( $self, $input_label, $submodel ) = @_;
        $input_label2submodel{ident $self}{$input_label} = $submodel;
        return;
    }

    sub get_submodel {
        my ( $self, $input_label ) = @_;
        return $input_label2submodel{ident $self}{$input_label};
    }

    sub delete_submodel {
        my ( $self, $input_label ) = @_;
        undef $input_label2submodel{ident $self}{$input_label};

        return;
    }

    sub get_translations {
        my ($self, $input_label, $features_old_rf, $features_rf) = @_;
        if ( ! defined($features_rf) ) {
             if ( ! defined($features_old_rf) ) {
                 return ();
             }
            $features_rf = $features_old_rf;
        }

#        print STDERR "Inp: " . $input_label . "\n";
#        print STDERR "FEAT: " . join("\t", keys %{$features_rf}) . "\n";

        my $submodel = $input_label2submodel{ident $self}{$input_label}
            or return ();

        my @variants;
        my $result = $submodel->predict(attributes => $features_rf);
        for my $output_label (keys %{$result}) {
            my $variant = {
                'label' => $output_label,
                'score' => $result->{$output_label},
                'source' => 'nb',
            };

            push @variants, $variant;
        }

        my @scores = map {$_->{score}} @variants;
        my @probs = Treex::Tool::ML::NormalizeProb::logscores2probs(@scores);

        foreach my $i (0..$#variants) {
            $variants[$i]->{prob} = $probs[$i];
        }

        return (sort {$b->{prob} <=> $a->{prob}} @variants);
#        my @results = (sort {$b->{prob} <=> $a->{prob}} @variants);
#        print STDERR "NB\t$input_label\t" . join("\t", map { $_->{label}.'_'.$_->{prob} } @results ) . "\n";
#        return @results;
    }


    sub predict { # stejny jako Treex::Tool::TranslationModel::Static::Model, chtelo by to spol. predka!!!
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
        return (keys %{$input_label2submodel{ident $self}});

    }

    sub load {
        my ($self, $filename) = @_;
        log_info "Loading nb translation model from $filename...";
        if ( $filename =~ /\.slurp\./ ) {
            my $ref = Compress::Zlib::memGunzip(read_file( $filename )) ;
            $input_label2submodel{ident $self} = Storable::thaw($ref) or log_fatal($!);
        } else {
            open my $fh, "<:gzip", $filename or log_fatal($!);
            $input_label2submodel{ident $self} = Storable::retrieve_fd($fh) or log_fatal($!);
            close($fh);
        }

        return;
    }

    sub save {
        my ($self, $filename) = @_;
        log_info "Storing nb translation model into $filename...";
#        print Data::Dumper->Dump([$input_label2submodel{ident $self}]);
        if ( $filename =~ /\.slurp\./ ) {
            write_file( $filename, {binmode => ':raw'},
                Compress::Zlib::memGzip(Storable::freeze($input_label2submodel{ident $self})) )
            or log_fatal $!;
        } else {
            open (my $fh, ">:gzip", $filename) or log_fatal $!;
            Storable::nstore_fd($input_label2submodel{ident $self},$fh) or log_fatal $!;;
            close($fh);
        }

        return;
    }

    sub stringify {
        my ($self) = @_;
#        my $output;

        print "NOT IMPLEMENTED!!!";
        return;
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
