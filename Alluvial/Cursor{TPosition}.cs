using System;
using System.Diagnostics;

namespace Alluvial
{
    [DebuggerDisplay("{ToString()}")]
    internal class Cursor<T> : ICursor<T>
    {
        private static readonly Func<Cursor<T>, T, bool> hasCursorReached;

        static Cursor()
        {
            var  positionIsComparable = typeof (IComparable<T>).IsAssignableFrom(typeof (T));

            if (positionIsComparable)
            {
                hasCursorReached = (cursor, point) =>
                {
                    if (cursor.Position == null)
                    {
                        return false;
                    }

                    var comparablePosition = (IComparable<T>)cursor.Position;
                    return comparablePosition.CompareTo(point) >= 0;
                };
            }
            else
            {
                hasCursorReached = (cursor, point) =>
                {
                    throw new InvalidOperationException("Cursor position cannot be compared to " + typeof(T));
                };
            }
        }

        public Cursor(T position = default(T))
        {
            Position = position;
        }

        public virtual bool HasReached(T point)
        {
            return hasCursorReached(this, point);
        }

        public virtual void AdvanceTo(T point)
        {
            Position = point;
        }

        public virtual T Position { get; protected set; }

        public override string ToString()
        {
            return string.Format("@{0}", Position);
        }
    }
}