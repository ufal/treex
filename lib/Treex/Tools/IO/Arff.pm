#
# This is a copy of the Arff::Util package from CPAN with some bugfixes. I am planning to contribute the fixes
# to CPAN and remove this file in the future.
#
# Ondrej Dusek, 2011/03/25
#
package Treex::Tools::IO::Arff;

use Moose;

use Data::Dumper;
use String::Util ':all';
use Text::CSV;

=head1 NAME

Arff::Util - ARFF files processing utilities.
This is a moose-based class.

=head1 VERSION

Version 1.1

=cut

our $VERSION = '1.1';

=head1 SYNOPSIS

Quick summary of what the module does.

  use ARFF::Util;

  my $arff_object = ARFF::Util->new();
  # load .arff formatted file into the buffer, and return pointer to buffer
  $arff_hash = $arff_object->load_arff($file_address);
  
  # save given buffer into the .arff formatted file
  $arff_object->save_arff($arff_hash, $file_address);

=head1 DESCRIPTION

ARFF::Util provides a collection of methods for processing ARFF formatted files.
"An ARFF (Attribute-Relation File Format) file is an ASCII text file that describes a list of instances sharing a set of attributes."
for more information about ARFF format visit http://www.cs.waikato.ac.nz/~ml/weka/arff.html

=head1 EXPORT



=head1 Object Attributes

=head2 relation

 This is a buffer hash
 Structure of hash:

 relation -> {
		attributes => [
				{
					attribute_name => x1,
					attribute_type => x2,
				},...
			      ]
		records    => [
				{
					attribute_name1 => value1,
					attribute_name2 => value2,...
				},...
			      ]
		data_record_count => x
	      }
=cut

has relation => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        {
            attributes        => [],
            records           => [],
            data_record_count => 0
        };
        }
);

=head2 error_count

Number of errors occured during the parsing or saving

=cut

has error_count => (
    is      => 'rw',
    default => 0
);

=head2 debug_mode

Set it to one to see detail info

=cut

has debug_mode => (
    is      => 'rw',
    default => 0
);

=head1 FUNCTIONS

=head2 load_arff

Get arff file path and load it in buffer

=cut

sub load_arff {
    my ( $self, $arff_file ) = @_;
    my $status = q/normal/;
    if ( $self->debug_mode ) {
        print "Loading $arff_file ...\n";
    }
    my $record_count    = 0;
    my $attribute_count = 0;
    my $line_counter    = 1;
    my $relation        = $self->relation;
    my $line_parser     = Text::CSV->new( { binary => 1, quote_char => '\'', escape_char => '\\', allow_loose_escapes => 1 } ) or die "Cannot use CSV Parser: " . Text::CSV->error_diag();

    local *FILE;
    open( FILE, $arff_file ) or die $!;
    while ( my $current_line = <FILE> )
    {
        $current_line = trim($current_line);

        #Check for comments
        if ( $current_line =~ /^\s*%/i )
        {
            $status = q/comment/;
        }
        elsif ( $current_line =~ /^\s*\@RELATION\s+(\S*)/i )
        {
            $relation->{relation_name} = $1;
        }
        elsif ( $current_line =~ /^\s*\@ATTRIBUTE\s+(\S*)\s+(\S*)/i )
        {
            if ( !$relation->{attributes} ) {
                $relation->{attributes} = [];
            }
            my $attribute = { "attribute_name" => $1, "attribute_type" => $2 };
            my $attributes = $relation->{"attributes"};

            #log_msg(Dumper $attribute);

            push @$attributes, $attribute;
            $attribute_count++;
        }
        elsif ( $current_line =~ /^\s*\@DATA(\.*)/i )
        {
            $status = q/data/;
        }
        elsif ( $status eq q/data/ && $current_line ne q// ) {
            if ( !$relation->{"records"} ) {
                $relation->{"records"} = [];
            }

            #log_msg("extracting data $current_line");
            $line_parser->parse($current_line);
            my @data_parts = $line_parser->fields();    # split(/,/, $current_line);

            my $attributes = $relation->{"attributes"};
            my $records    = $relation->{"records"};

            my $cur_record = {};

            #log_msg("DATA PARTS".Dumper @data_parts);
            if ( scalar @data_parts == $attribute_count ) {
                for ( my $i = 0; $i <= $#data_parts; $i++ )
                {
                    $cur_record->{ $$attributes[$i]->{"attribute_name"} } = trim( $data_parts[$i] );
                }

                #log_msg("parts: ".$#data_parts);
                $record_count++;
                push @$records, $cur_record;
            }
            else
            {
                if ( $self->debug_mode ) {
                    print "Line $line_counter : Invalid data record: $current_line Contains " . ( scalar @data_parts ) . " Expected $attribute_count\n";
                }
                $self->error_count( $self->error_count + 1 );
            }

        }
        $line_counter++;
    }

    $relation->{"data_record_count"} = $record_count;
    $relation->{"attribute_count"}   = $attribute_count;

    if ( $self->debug_mode ) {
        eval("use Devel::Size qw(size total_size)");

        print "$arff_file loaded with " . $self->error_count . " error(s).\n";
        print "Buffer size: " . total_size($relation) . " bytes\n";
    }
    $self->relation($relation);
    return $relation;
}

=head2 save_arff

Save given buffer into the .arff formatted file. 

=cut

sub save_arff {
    my ( $self, $buffer, $arff_file ) = @_;

    local *FILE;

    open( FILE, ">$arff_file" );

    my $record_count = 0;

    if ( $self->debug_mode ) {
        print "Writing buffer to $arff_file ...\n";
    }

    if ( $buffer->{relation_name} )
    {
        print FILE q/@RELATION / . $buffer->{relation_name} . "\n";
    }
    print FILE "\n";
    print FILE "\n";

    if ( $buffer->{attributes} ) {
        foreach my $attribute ( @{ $buffer->{"attributes"} } ) {
            print FILE q/@ATTRIBUTE / . $attribute->{attribute_name} . q/ / . $attribute->{attribute_type} . "\n";
        }
        print FILE "\n";
        print FILE "\n";

        if ( $buffer->{records} ) {
            print FILE "\@DATA\n";
            print FILE "\n";

            foreach my $record ( @{ $buffer->{"records"} } ) {
                my $record_string = q//;
                foreach my $attribute ( @{ $buffer->{"attributes"} } ) {
                    if ( $record->{ $attribute->{attribute_name} } ) {
                        $record_string .= $record->{ $attribute->{attribute_name} } . q/,/;
                    }
                    else {
                        if ( $self->debug_mode ) {
                            print "Invalid buffer passed, " . $attribute->{attribute_name} . " is not defined for record... write UNKNOWN\n";
                        }
                        $record_string .= q/UNKNOWN,/;
                        $self->error_count( $self->error_count + 1 );
                    }
                }

                $record_string =~ s/,$//;

                print FILE $record_string . "\n";
                $record_count++;
            }
        }
    }

    if ( $self->debug_mode ) {
        eval("use Devel::Size qw(size total_size)");

        print "Buffer saved to $arff_file with " . $self->error_count . " error(s).\n";
        print "Buffer size: " . total_size($buffer) . " bytes\n";
        print "Data rows count: " . $record_count . "\n";
    }

    return 1;
}

=head1 AUTHOR

Ehsan Emadzadeh, C<< <ehsan0emadzadeh at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-arff-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Arff-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can contact me: eemadzadeh [at] gmail  

or

You can find documentation for this module with the perldoc command.

    perldoc Arff::Util


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Arff-Util>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Arff-Util>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Arff-Util>

=item * Search CPAN

L<http://search.cpan.org/dist/Arff-Util/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Ehsan Emadzadeh, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Arff::Util
